//
// PicoRV32 softcore subsystem.
//
// A small RISC-V computer that services the disk controllers and draws the
// on-screen keyboard. It runs firmware from an on-chip ROM, with work RAM for its
// stack and buffers, and reaches the disk bridge (softcpu_fdd_bridge) through
// memory-mapped registers at 0x3xxxxxxx; the bridge pulls sectors from an APF
// dataslot and streams them into the floppy and IDE controllers' mgmt FIFOs. It
// also owns the OSD framebuffer, read out below in the video clock domain.
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

    // ide.v request (CHIPSET ide0_request): 6=reset, 4=command, 5=data, 0=idle
    input [2:0] ide0_request,

    // Mounted image size in sectors, per drive (from the host dataslot table)
    input [31:0] fdd0_disk_size,
    input [31:0] fdd1_disk_size,
    input [31:0] hdd0_disk_size,
    input [31:0] hdd1_disk_size,

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
    output        target_dataslot_flush,
    output [15:0] target_dataslot_id,
    output [31:0] target_dataslot_slotoffset,
    output [31:0] target_dataslot_bridgeaddr,
    output [31:0] target_dataslot_length,
    input         target_dataslot_ack,
    input         target_dataslot_done,
    input   [2:0] target_dataslot_err,

    output [31:0] bridge_rd_data_out,

    // OSD overlay: framebuffer read out in the video clock domain (clk_pix),
    // located by the raster counters from the video output stage. The CPU write
    // side of the framebuffer lands in clk_pico.
    input         clk_pix,
    input   [9:0] osd_hcnt,
    input   [9:0] osd_vcnt,
    output  [3:0] osd_palette_idx,
    output        osd_in_area,

    // Controller-1 buttons in; OSD-shown flag out (both firmware-facing).
    input  [15:0] cont1_key,
    output        osd_active,

    // Virtual-keyboard key event: {make, Set-2 code}, with a strobe that toggles
    // per firmware write so pocket_keyboard pushes exactly one queue entry.
    output  [8:0] vkb_key,
    output        vkb_stb
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
    // PicoRV32 trap output, deliberately unmonitored: the softcore should never trap, and
    // Reset PC is the recovery if it somehow does.
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
    // Address decode. ROM at 0x0xxxxxxx, work RAM at 0x1xxxxxxx, status/control at
    // 0x2xxxxxxx, the disk bridge at 0x3xxxxxxx, the OSD framebuffer at 0x4xxxxxxx.
    //
    wire sel_rom    = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h0);
    wire sel_ram    = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h1);
    wire sel_status = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h2);
    wire sel_fdd    = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h3);
    wire sel_fb     = cpu_mem_valid && (cpu_mem_addr[31:28] == 4'h4);

    // OSD control at 0x20000004: bit0 = shown, bit1 = position (0 = low, 1 = high).
    reg osd_active_r = 1'b0;
    reg osd_pos_r    = 1'b0;
    always @(posedge clk_pico) begin
        if (reset) begin
            osd_active_r <= 1'b0;
            osd_pos_r    <= 1'b0;
        end else if (sel_status && cpu_mem_wstrb[0] && cpu_mem_addr[3:2] == 2'd1) begin
            osd_active_r <= cpu_mem_wdata[0];
            osd_pos_r    <= cpu_mem_wdata[1];
        end
    end
    assign osd_active = osd_active_r;

    // The position bit selects the vertical origin in the video clock domain.
    wire osd_pos_pix;
    synch_3 s_osd_pos_pix (osd_pos_r, osd_pos_pix, clk_pix);

    // Virtual-keyboard key event, written by the firmware at 0x20000008. The CPU
    // holds a store across two clk_pico cycles, so the write is edge-detected to
    // toggle the strobe exactly once; pocket_keyboard reads the strobe directly
    // (clk_pico is a gated clk_sys) and turns each toggle into one queue push.
    wire      vkb_wr = sel_status && cpu_mem_wstrb[0] && cpu_mem_addr[3:2] == 2'd2;
    reg       vkb_wr_d  = 1'b0;
    reg [8:0] vkb_key_r = 9'd0;
    reg       vkb_stb_r = 1'b0;
    always @(posedge clk_pico) begin
        if (reset) begin
            vkb_wr_d  <= 1'b0;
            vkb_key_r <= 9'd0;
            vkb_stb_r <= 1'b0;
        end else begin
            vkb_wr_d <= vkb_wr;
            if (vkb_wr && !vkb_wr_d) begin
                vkb_key_r <= cpu_mem_wdata[8:0];
                vkb_stb_r <= ~vkb_stb_r;
            end
        end
    end
    assign vkb_key = vkb_key_r;
    assign vkb_stb = vkb_stb_r;

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
    // Firmware ROM: 16 KB (4096 x 32), initialised from the built firmware image.
    // The path is relative to the Quartus project directory (src/fpga).
    //
    wire [31:0] rom_rdata;

    sprom #(
        .aw(12),
        .dw(32),
        .MEM_INIT_FILE("../firmware/firmware.vh")
    ) pico_rom (
        .clk  (clk_pico),
        .rst  (reset),
        .ce   (sel_rom),
        .oe   (1'b1),
        .addr (cpu_mem_addr[13:2]),
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
    // OSD framebuffer: 636x81 at 4bpp (two pixels per byte), four byte lanes.
    // Port A is the CPU read/write path (clk_pico) the firmware draws through;
    // Port B reads it in the video clock domain for the overlay.
    //
    reg [7:0] fb0 [0:8191];
    reg [7:0] fb1 [0:8191];
    reg [7:0] fb2 [0:8191];
    reg [7:0] fb3 [0:8191];

    // Port A: CPU read/write, clk_pico domain, registered read (one cycle).
    wire [12:0] fb_word_addr = cpu_mem_addr[14:2];
    reg [7:0] fb0_qa, fb1_qa, fb2_qa, fb3_qa;
    always @(posedge clk_pico) begin
        if (sel_fb) begin
            if (cpu_mem_wstrb[0]) fb0[fb_word_addr] <= cpu_mem_wdata[7:0];
            if (cpu_mem_wstrb[1]) fb1[fb_word_addr] <= cpu_mem_wdata[15:8];
            if (cpu_mem_wstrb[2]) fb2[fb_word_addr] <= cpu_mem_wdata[23:16];
            if (cpu_mem_wstrb[3]) fb3[fb_word_addr] <= cpu_mem_wdata[31:24];
            fb0_qa <= fb0[fb_word_addr];
            fb1_qa <= fb1[fb_word_addr];
            fb2_qa <= fb2[fb_word_addr];
            fb3_qa <= fb3[fb_word_addr];
        end
    end
    wire [31:0] fb_rdata = {fb3_qa, fb2_qa, fb1_qa, fb0_qa};

    // Display area within the active CGA raster, 636x81 drawn 1:1. The firmware
    // selects the vertical origin so the overlay can sit low or high.
    localparam [9:0] OSD_W  = 10'd636;
    localparam [9:0] OSD_H  = 10'd81;
    localparam [9:0] OSD_X0 = 10'd2;
    wire [9:0] OSD_Y0 = osd_pos_pix ? 10'd5 : 10'd111;
    wire [9:0] OSD_X1 = OSD_X0 + OSD_W - 10'd1;
    wire [9:0] OSD_Y1 = OSD_Y0 + OSD_H - 10'd1;

    wire osd_in_bounds = (osd_hcnt >= OSD_X0) && (osd_hcnt <= OSD_X1) &&
                         (osd_vcnt >= OSD_Y0) && (osd_vcnt <= OSD_Y1);

    // Non-power-of-two stride (636/2 = 318 bytes/row), so the row offset is a
    // constant multiply rather than a bit-concatenation.
    wire  [9:0] osd_x = osd_hcnt - OSD_X0;                                  // 0..635
    wire  [9:0] osd_y = osd_vcnt - OSD_Y0;                                  // 0..80
    wire [15:0] osd_byte_addr = osd_y[6:0] * 16'd318 + {7'd0, osd_x[9:1]};  // y*318 + x/2
    wire [12:0] osd_word_addr = osd_byte_addr[14:2];

    // Port B: registered read in the video clock domain; lane/nibble/area
    // selectors are pipelined one stage to match the read latency.
    reg [7:0] fb0_qb, fb1_qb, fb2_qb, fb3_qb;
    reg [1:0] osd_lane_r;
    reg       osd_nib_r;
    reg       osd_in_area_r;
    always @(posedge clk_pix) begin
        fb0_qb <= fb0[osd_word_addr];
        fb1_qb <= fb1[osd_word_addr];
        fb2_qb <= fb2[osd_word_addr];
        fb3_qb <= fb3[osd_word_addr];
        osd_lane_r    <= osd_byte_addr[1:0];
        osd_nib_r     <= osd_x[0];
        osd_in_area_r <= osd_in_bounds;
    end

    reg [7:0] osd_byte;
    always_comb begin
        case (osd_lane_r)
            2'd0:    osd_byte = fb0_qb;
            2'd1:    osd_byte = fb1_qb;
            2'd2:    osd_byte = fb2_qb;
            default: osd_byte = fb3_qb;
        endcase
    end

    assign osd_palette_idx = osd_nib_r ? osd_byte[3:0] : osd_byte[7:4];
    assign osd_in_area     = osd_in_area_r;

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
        .ide0_request(ide0_request),
        .fdd0_disk_size(fdd0_disk_size),
        .fdd1_disk_size(fdd1_disk_size),
        .hdd0_disk_size(hdd0_disk_size),
        .hdd1_disk_size(hdd1_disk_size),

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
        .target_dataslot_flush      (target_dataslot_flush),
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
            32'h2000_0000: cpu_mem_rdata = {16'd0, cont1_key};
            32'h3???_????: cpu_mem_rdata = fdd_rdata;
            32'h4???_????: cpu_mem_rdata = fb_rdata;
            default:       cpu_mem_rdata = 32'd0;
        endcase
    end

endmodule
