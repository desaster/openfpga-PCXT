//
// Softcore disk bridge: the data mover between an APF dataslot and floppy.v.
//
// The firmware on the PicoRV32 in softcpu_subsystem drives this through a bank of
// memory-mapped registers. Two data paths meet here:
//
//   APF side: a 256 x 32 bridge RAM. The APF host DMA fills it (for disk reads) or
//   reads it back (for disk writes) over the bridge_* port, and the firmware moves
//   dataslot transfers with the target_dataslot_* handshake. Byte 0 of a dataslot
//   arrives in bridge_wr_data[31:24], so port-A writes reverse the four bytes to
//   land it little-endian in the RAM.
//
//   Controller side: a generic master for floppy.v's management bus. The firmware
//   composes one mgmt transaction at a time (a floppy register, optional write
//   data, and a read or write trigger); this drives it as a single clk_sys-cycle
//   strobe and captures the read data. floppy.v selects on mgmt_address[15:8]==0xF2,
//   with the drive in bit 7 and the register in bits [3:0].
//
// Clock-domain note: clk_pico is a gated clk_sys (its edges are clk_sys edges), so
// registers the firmware writes are stable across clk_sys and need no synchroniser.
// A firmware trigger is a one-clk_pico-period pulse; clk_sys edge-detects its rising
// edge into exactly one mgmt strobe. That single-cycle strobe matters because the
// mgmt FIFO at register 0xF pushes or pops on every strobe: unlike an addressed
// buffer, a level held for the whole period would move the byte several times. Only
// the clk_sys / clk_74a crossing is truly asynchronous and uses synch_3.
//
// Adapted from the softcore FDD bridge in the myc64-pocket and OpenFPGA ZX Spectrum
// Pocket cores; the WD1793 sector-buffer side is replaced with the floppy.v
// mgmt/FIFO side.
//

module softcpu_fdd_bridge #(
    parameter [31:0] BRIDGE_ADDR = 32'h60000000
) (
    input  wire        clk_pico,
    input  wire        clk_sys,
    input  wire        clk_74a,
    input  wire        reset,

    // Firmware register interface (the parent pre-decodes the 0x3 region)
    input  wire        cpu_valid,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire  [3:0] cpu_wstrb,
    output reg  [31:0] cpu_rdata,

    // floppy.v request flags, clk_sys: {write-pending, read-pending}
    input  wire  [1:0] fdd_request,

    // Management-bus master to floppy.v via CHIPSET, clk_sys
    output wire [15:0] mgmt_addr,
    output wire [15:0] mgmt_dout,
    output reg         mgmt_wr,
    output reg         mgmt_rd,
    input  wire [15:0] mgmt_din,

    // APF host DMA into the bridge RAM, clk_74a
    input  wire        bridge_wr,
    input  wire [31:0] bridge_addr,
    input  wire [31:0] bridge_wr_data,

    // APF target-dataslot transfer handshake
    output wire        target_dataslot_read,
    output wire        target_dataslot_write,
    output reg  [15:0] target_dataslot_id,
    output reg  [31:0] target_dataslot_slotoffset,
    output reg  [31:0] target_dataslot_bridgeaddr,
    output reg  [31:0] target_dataslot_length,
    input  wire        target_dataslot_ack,
    input  wire        target_dataslot_done,
    input  wire  [2:0] target_dataslot_err,

    output wire [31:0] bridge_rd_data_out
);

    //
    // Bridge RAM: 256 x 32, bidirectional dual-port.
    //   Port A (clk_74a): APF DMA writes for reads, read-back for writes.
    //   Port B (clk_pico): firmware access via the FDD_BRAM registers.
    // Port-A writes reverse the four bytes so dataslot byte 0 lands little-endian.
    //
    wire [31:0] bram_q_a;
    wire [31:0] bram_q_b;

    reg  [7:0]  bram_addr_b;
    reg  [31:0] bram_data_b;
    reg         bram_wren_b;

    assign bridge_rd_data_out = bram_q_a;

    altsyncram bridgeram (
        .clock0    (clk_74a),
        .address_a (bridge_addr[9:2]),
        .data_a    ({bridge_wr_data[7:0], bridge_wr_data[15:8],
                     bridge_wr_data[23:16], bridge_wr_data[31:24]}),
        .wren_a    (bridge_wr && bridge_addr[31:28] == BRIDGE_ADDR[31:28]),
        .q_a       (bram_q_a),

        .clock1    (clk_pico),
        .address_b (bram_addr_b),
        .data_b    (bram_data_b),
        .wren_b    (bram_wren_b),
        .q_b       (bram_q_b),

        .aclr0 (1'b0),
        .aclr1 (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a (1'b1),
        .byteena_b (1'b1),
        .clocken0 (1'b1),
        .clocken1 (1'b1),
        .clocken2 (1'b1),
        .clocken3 (1'b1),
        .eccstatus (),
        .rden_a (1'b1),
        .rden_b (1'b1)
    );
    defparam
        bridgeram.operation_mode = "BIDIR_DUAL_PORT",
        bridgeram.width_a = 32,
        bridgeram.widthad_a = 8,
        bridgeram.width_b = 32,
        bridgeram.widthad_b = 8,
        bridgeram.address_reg_b = "CLOCK1",
        bridgeram.outdata_reg_a = "UNREGISTERED",
        bridgeram.outdata_reg_b = "CLOCK1",
        bridgeram.numwords_a = 256,
        bridgeram.numwords_b = 256,
        bridgeram.lpm_type = "altsyncram",
        bridgeram.intended_device_family = "Cyclone V";

    //
    // Management-bus master. The firmware latches a drive + register and optional
    // write data, then triggers a read or write. mgmt_addr / mgmt_dout come from
    // those clk_pico registers (stable across the whole period); the trigger pulses
    // are edge-detected in clk_sys into a single-cycle mgmt_wr / mgmt_rd, and a read
    // captures mgmt_din the cycle the strobe is asserted.
    //
    reg        mgmt_drive;
    reg  [3:0] mgmt_reg;
    reg [15:0] mgmt_wdata_r;
    reg        mgmt_wr_req;
    reg        mgmt_rd_req;
    reg        mgmt_wr_req_d;
    reg        mgmt_rd_req_d;
    reg [15:0] mgmt_rdata_cap;

    assign mgmt_addr = {8'hF2, mgmt_drive, 3'b000, mgmt_reg};
    assign mgmt_dout = mgmt_wdata_r;

    always @(posedge clk_sys) begin
        mgmt_wr <= 1'b0;
        mgmt_rd <= 1'b0;
        mgmt_wr_req_d <= mgmt_wr_req;
        mgmt_rd_req_d <= mgmt_rd_req;

        if (mgmt_wr_req & ~mgmt_wr_req_d)
            mgmt_wr <= 1'b1;
        if (mgmt_rd_req & ~mgmt_rd_req_d)
            mgmt_rd <= 1'b1;
        if (mgmt_rd)
            mgmt_rdata_cap <= mgmt_din;

        if (reset) begin
            mgmt_wr        <= 1'b0;
            mgmt_rd        <= 1'b0;
            mgmt_rdata_cap <= 16'd0;
        end
    end

    //
    // Target-dataslot handshake. tds_read / tds_write assert on the firmware trigger
    // and clear when the APF acknowledges; the clk_74a-domain outputs go through
    // synch_3. done is latched on its rising edge, since the APF holds it high until
    // the next command and a level test would re-fire a completed transfer.
    //
    reg tds_read_r;
    reg tds_write_r;
    synch_3 tds_read_sync (.i(tds_read_r), .o(target_dataslot_read), .clk(clk_74a));
    synch_3 tds_write_sync (.i(tds_write_r), .o(target_dataslot_write), .clk(clk_74a));

    wire target_dataslot_ack_s;
    wire target_dataslot_done_rise;
    synch_3 tds_ack_sync (.i(target_dataslot_ack), .o(target_dataslot_ack_s), .clk(clk_sys));
    synch_3 tds_done_sync (.i(target_dataslot_done), .o(), .clk(clk_sys),
                           .rise(target_dataslot_done_rise));

    reg        tds_done;
    reg  [2:0] tds_err;

    reg tds_read_pulse;
    reg tds_write_pulse;
    reg clr_done_pulse;

    always @(posedge clk_sys) begin
        if (tds_read_pulse) begin
            tds_read_r <= 1'b1;
            tds_done   <= 1'b0;
        end
        if (tds_write_pulse) begin
            tds_write_r <= 1'b1;
            tds_done    <= 1'b0;
        end
        if (target_dataslot_ack_s) begin
            tds_read_r  <= 1'b0;
            tds_write_r <= 1'b0;
        end
        if (target_dataslot_done_rise) begin
            tds_done <= 1'b1;
            tds_err  <= target_dataslot_err;
        end
        if (clr_done_pulse)
            tds_done <= 1'b0;

        if (reset) begin
            tds_read_r  <= 1'b0;
            tds_write_r <= 1'b0;
            tds_done    <= 1'b0;
            tds_err     <= 3'd0;
        end
    end

    //
    // Firmware register read (combinational).
    //
    always_comb begin
        cpu_rdata = 32'd0;
        if (cpu_valid) begin
            case (cpu_addr[7:0])
                8'h00:   cpu_rdata = {30'd0, fdd_request};
                8'h10:   cpu_rdata = {16'd0, mgmt_rdata_cap};
                8'h18:   cpu_rdata = bram_q_b;
                8'h34:   cpu_rdata = {28'd0, tds_err, tds_done};
                default: cpu_rdata = 32'd0;
            endcase
        end
    end

    //
    // Firmware register write and bridge-RAM sequential access (clk_pico). Writes
    // fire on the cpu_valid rising edge; a following cycle auto-increments the
    // bridge-RAM address so the firmware streams words with one access each.
    //
    reg cpu_valid_prev;

    always @(posedge clk_pico) begin
        bram_wren_b     <= 1'b0;
        mgmt_wr_req     <= 1'b0;
        mgmt_rd_req     <= 1'b0;
        tds_read_pulse  <= 1'b0;
        tds_write_pulse <= 1'b0;
        clr_done_pulse  <= 1'b0;

        cpu_valid_prev <= cpu_valid;

        if (reset) begin
            mgmt_drive     <= 1'b0;
            mgmt_reg       <= 4'd0;
            mgmt_wdata_r   <= 16'd0;
            bram_addr_b    <= 8'd0;
            bram_data_b    <= 32'd0;
            cpu_valid_prev <= 1'b0;
            target_dataslot_id         <= 16'd0;
            target_dataslot_slotoffset <= 32'd0;
            target_dataslot_bridgeaddr <= BRIDGE_ADDR;
            target_dataslot_length     <= 32'd512;
        end else if (cpu_valid && !cpu_valid_prev && (cpu_wstrb != 0)) begin
            case (cpu_addr[7:0])
                8'h04: begin mgmt_drive <= cpu_wdata[4]; mgmt_reg <= cpu_wdata[3:0]; end
                8'h08: mgmt_wdata_r <= cpu_wdata[15:0];
                8'h0C: begin
                    if (cpu_wdata[0]) mgmt_wr_req <= 1'b1;
                    if (cpu_wdata[1]) mgmt_rd_req <= 1'b1;
                end
                8'h14: bram_addr_b <= cpu_wdata[7:0];
                8'h1C: begin bram_data_b <= cpu_wdata; bram_wren_b <= 1'b1; end
                8'h20: target_dataslot_id         <= cpu_wdata[15:0];
                8'h24: target_dataslot_slotoffset <= cpu_wdata;
                8'h28: target_dataslot_bridgeaddr <= cpu_wdata;
                8'h2C: target_dataslot_length     <= cpu_wdata;
                8'h30: begin
                    if (cpu_wdata[0]) tds_read_pulse  <= 1'b1;
                    if (cpu_wdata[1]) tds_write_pulse <= 1'b1;
                end
                8'h38: if (cpu_wdata[0]) clr_done_pulse <= 1'b1;
            endcase
        end

        if (!reset && cpu_valid && cpu_valid_prev) begin
            case (cpu_addr[7:0])
                8'h18: bram_addr_b <= bram_addr_b + 8'd1;
                8'h1C: bram_addr_b <= bram_addr_b + 8'd1;
            endcase
        end
    end

endmodule
