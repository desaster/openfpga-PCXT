//
// PicoRV32 disk-service softcore subsystem.
//
// A small RISC-V computer that services the floppy controller. It runs firmware
// from an on-chip ROM, with work RAM for its stack and buffers, and reaches the
// disk bridge (softcpu_fdd_bridge) through memory-mapped registers at 0x3xxxxxxx.
// The bridge pulls sectors from an APF dataslot and streams them into floppy.v's
// mgmt FIFO.
//
// The CPU runs on clk_pico, a clock derived from clk_sys by gating it down to a
// single-cycle pulse every six cycles (about 8.3 MHz). Every clk_pico edge is
// also a clk_sys edge, so a register written in the clk_pico domain is stable for
// the whole period and can be read from clk_sys logic without a synchroniser.
//
// Adapted from the softcore approach in the myc64-pocket and OpenFPGA ZX Spectrum
// Pocket cores.
//

module softcpu_subsystem (
    input clk_sys,   // clk_chipset, 50 MHz
    input clk_74a,   // APF bridge clock
    input reset,

    // floppy.v request flags (CHIPSET fdd_request): {write-pending, read-pending}
    input [1:0] fdd_request,

    // Management-bus master to floppy.v via CHIPSET
    output [15:0] mgmt_addr,
    output [15:0] mgmt_dout,
    output        mgmt_wr,
    output        mgmt_rd,
    input  [15:0] mgmt_din,

    // APF host DMA into the disk bridge RAM
    input         bridge_wr,
    input  [31:0] bridge_addr,
    input  [31:0] bridge_wr_data,

    // APF target-dataslot transfer handshake
    output        target_dataslot_read,
    output        target_dataslot_write,
    output [15:0] target_dataslot_id,
    output [31:0] target_dataslot_slotoffset,
    output [31:0] target_dataslot_bridgeaddr,
    output [31:0] target_dataslot_length,
    input         target_dataslot_ack,
    input         target_dataslot_done,
    input   [2:0] target_dataslot_err,

    output [31:0] bridge_rd_data_out
);

    //
    // CPU clock: gate clk_sys down to one pulse every six cycles, about 8.3 MHz.
    //
    reg [2:0] clk_div;
    reg       clk_pico;
    always @(posedge clk_sys) begin
        clk_div  <= (clk_div == 3'd5) ? 3'd0 : clk_div + 3'd1;
        clk_pico <= (clk_div == 3'd0);
    end

    //
    // PicoRV32 CPU. RV32IM: the firmware is built for -march=rv32im with no
    // libgcc, so the CPU must provide both the multiplier and the divider. No
    // compressed ISA, no interrupts.
    //
    wire        cpu_mem_valid;
    wire        cpu_mem_instr;
    reg         cpu_mem_ready;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire  [3:0] cpu_mem_wstrb;
    reg  [31:0] cpu_mem_rdata;
    wire        cpu_trap;

    picorv32 #(
        .COMPRESSED_ISA(0),
        .ENABLE_IRQ(0),
        .ENABLE_MUL(1),
        .ENABLE_DIV(1)
    ) pico (
        .clk       (clk_pico),
        .resetn    (~reset),
        .trap      (cpu_trap),
        .mem_valid (cpu_mem_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (cpu_mem_ready),
        .mem_addr  (cpu_mem_addr),
        .mem_wdata (cpu_mem_wdata),
        .mem_wstrb (cpu_mem_wstrb),
        .mem_rdata (cpu_mem_rdata)
    );

    //
    // Address decode. ROM at 0x0xxxxxxx, work RAM at 0x1xxxxxxx, the disk bridge at
    // 0x3xxxxxxx. The 0x2xxxxxxx status region is unused and reads back zero.
    //
    wire sel_rom = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h0);
    wire sel_ram = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h1);
    wire sel_fdd = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h3);

    //
    // Memory ready. The ROM read is registered, so it needs two clk_pico cycles;
    // RAM completes in one. Any other (undecoded) access still gets a ready, so a
    // stray load or store cannot wedge the CPU.
    //
    reg [1:0] rom_wait_cnt;
    reg       cpu_mem_ready_rom;
    reg       cpu_mem_ready_other;

    always @(posedge clk_pico) begin
        if (reset) begin
            rom_wait_cnt      <= 0;
            cpu_mem_ready_rom <= 0;
        end else if (sel_rom) begin
            if (rom_wait_cnt == 0 && cpu_mem_valid)
                rom_wait_cnt <= 1;
            else if (rom_wait_cnt == 1) begin
                rom_wait_cnt      <= 0;
                cpu_mem_ready_rom <= 1;
            end else
                cpu_mem_ready_rom <= 0;
        end else begin
            rom_wait_cnt      <= 0;
            cpu_mem_ready_rom <= 0;
        end
    end

    always @(posedge clk_pico) begin
        if (reset)
            cpu_mem_ready_other <= 0;
        else
            cpu_mem_ready_other <= ~cpu_mem_ready_other & cpu_mem_valid & ~sel_rom;
    end

    assign cpu_mem_ready = cpu_mem_ready_rom | cpu_mem_ready_other;

    //
    // Firmware ROM: 8 KB (2048 x 32), initialised from the built firmware image.
    // The path is relative to the Quartus project directory (src/fpga).
    //
    wire [31:0] rom_rdata;

    sprom #(
        .aw(11),
        .dw(32),
        .MEM_INIT_FILE("../firmware/firmware.vh")
    ) pico_rom (
        .clk  (clk_pico),
        .rst  (reset),
        .ce   (sel_rom),
        .oe   (1'b1),
        .addr (cpu_mem_addr[12:2]),
        .dout (rom_rdata)
    );

    //
    // Work RAM: 8 KB as four byte lanes (2048 x 8 each), so byte and halfword
    // stores land through cpu_mem_wstrb. Registered read, one clk_pico of latency.
    //
    wire [10:0] ram_word_addr = cpu_mem_addr[12:2];

    reg [7:0] ram0 [0:2047];
    reg [7:0] ram1 [0:2047];
    reg [7:0] ram2 [0:2047];
    reg [7:0] ram3 [0:2047];

    reg [7:0] ram0_q, ram1_q, ram2_q, ram3_q;

    always @(posedge clk_pico) begin
        if (sel_ram) begin
            if (cpu_mem_wstrb[0]) ram0[ram_word_addr] <= cpu_mem_wdata[7:0];
            if (cpu_mem_wstrb[1]) ram1[ram_word_addr] <= cpu_mem_wdata[15:8];
            if (cpu_mem_wstrb[2]) ram2[ram_word_addr] <= cpu_mem_wdata[23:16];
            if (cpu_mem_wstrb[3]) ram3[ram_word_addr] <= cpu_mem_wdata[31:24];
            ram0_q <= ram0[ram_word_addr];
            ram1_q <= ram1[ram_word_addr];
            ram2_q <= ram2[ram_word_addr];
            ram3_q <= ram3[ram_word_addr];
        end
    end

    wire [31:0] ram_rdata = {ram3_q, ram2_q, ram1_q, ram0_q};

    //
    // Disk bridge: APF dataslot to floppy.v mgmt bus, mapped at 0x3xxxxxxx.
    //
    wire [31:0] fdd_rdata;

    softcpu_fdd_bridge #(
        .BRIDGE_ADDR(32'h60000000)
    ) fdd_bridge (
        .clk_pico   (clk_pico),
        .clk_sys    (clk_sys),
        .clk_74a    (clk_74a),
        .reset      (reset),

        .cpu_valid  (sel_fdd),
        .cpu_addr   (cpu_mem_addr),
        .cpu_wdata  (cpu_mem_wdata),
        .cpu_wstrb  (cpu_mem_wstrb),
        .cpu_rdata  (fdd_rdata),

        .fdd_request(fdd_request),

        .mgmt_addr  (mgmt_addr),
        .mgmt_dout  (mgmt_dout),
        .mgmt_wr    (mgmt_wr),
        .mgmt_rd    (mgmt_rd),
        .mgmt_din   (mgmt_din),

        .bridge_wr      (bridge_wr),
        .bridge_addr    (bridge_addr),
        .bridge_wr_data (bridge_wr_data),

        .target_dataslot_read       (target_dataslot_read),
        .target_dataslot_write      (target_dataslot_write),
        .target_dataslot_id         (target_dataslot_id),
        .target_dataslot_slotoffset (target_dataslot_slotoffset),
        .target_dataslot_bridgeaddr (target_dataslot_bridgeaddr),
        .target_dataslot_length     (target_dataslot_length),
        .target_dataslot_ack        (target_dataslot_ack),
        .target_dataslot_done       (target_dataslot_done),
        .target_dataslot_err        (target_dataslot_err),

        .bridge_rd_data_out (bridge_rd_data_out)
    );

    //
    // CPU read mux.
    //
    always_comb begin
        casez (cpu_mem_addr)
            32'h0???_????: cpu_mem_rdata = rom_rdata;
            32'h1???_????: cpu_mem_rdata = ram_rdata;
            32'h3???_????: cpu_mem_rdata = fdd_rdata;
            default:       cpu_mem_rdata = 32'd0;
        endcase
    end

endmodule
