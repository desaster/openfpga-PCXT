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
    input   [3:0] select_fn,      // interact Button Select / Start function ids
    input   [3:0] start_fn,
    input         credits_active, // credits overlay up: firmware suppresses OSD button input
    input         osd_open_req,   // interact "Extra Options" requests the settings OSD
    output        osd_active,
    output        osd_reset_req,
    output        osd_credits_req,
    output        osd_video_req,

    // Virtual-keyboard key event: {make, Set-2 code}, with a strobe that toggles
    // per firmware write so pocket_keyboard pushes exactly one queue entry.
    output  [8:0] vkb_key,
    output        vkb_stb,

    // Machine settings edited in the OSD, driven out to core_top (clk_sys), one output per wired
    // setting; the indices into osd_settings[] below match settings_ui.c's SET_* enum.
    output  [2:0] osd_palette,
    output  [1:0] osd_cpu_speed,
    output  [1:0] osd_bios_wr,
    output  [1:0] osd_opl2,
    output  [1:0] osd_boost,
    output  [1:0] osd_spk_vol,
    output        osd_composite,
    output        osd_ems,
    output  [1:0] osd_ems_frame,
    output        osd_a000,
    output  [1:0] osd_joy1,
    output  [1:0] osd_joy2,
    output        osd_swapjoy,
    output        osd_syncjoy,
    output        osd_video_1st
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

    // The built-in timer interrupt drives the OSD service (see the firmware irq handler),
    // so a disk transfer can block without starving the keyboard. No external IRQ lines.
    picorv32 #(
        .COMPRESSED_ISA(0),
        .ENABLE_IRQ(1),
        .ENABLE_MUL(1),
        .ENABLE_DIV(1)
    ) pico (
        .clk       (clk_pico),
        .resetn    (~reset),
        .trap      (cpu_trap),
        .irq       (32'd0),
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

    // OSD control at 0x20000004: bit0 = overlay shown. An overlay is positioned by where the
    // firmware draws it in the full-screen framebuffer, so there is no compositor offset.
    reg osd_active_r = 1'b0;
    always @(posedge clk_pico) begin
        if (reset)
            osd_active_r <= 1'b0;
        else if (sel_status && cpu_mem_wstrb[0] && cpu_mem_addr[3:2] == 2'd1)
            osd_active_r <= cpu_mem_wdata[0];
    end
    assign osd_active = osd_active_r;

    // OSD action trigger at 0x20000010: bit0 requests a PC reset, bit1 the credits overlay,
    // bit2 toggles the displayed video card. Reset resets the softcore too, so its request
    // self-clears; core_top stretches reset into a clean pulse and edge-detects the others
    // (the firmware re-arms the register with a zero write before each request).
    reg osd_reset_req_r = 1'b0;
    reg osd_credits_req_r = 1'b0;
    reg osd_video_req_r = 1'b0;
    always @(posedge clk_pico) begin
        if (reset) begin
            osd_reset_req_r   <= 1'b0;
            osd_credits_req_r <= 1'b0;
            osd_video_req_r   <= 1'b0;
        end else if (sel_status && cpu_mem_wstrb[0] && cpu_mem_addr[4:2] == 3'd4) begin
            osd_reset_req_r   <= cpu_mem_wdata[0];
            osd_credits_req_r <= cpu_mem_wdata[1];
            osd_video_req_r   <= cpu_mem_wdata[2];
        end
    end
    assign osd_reset_req   = osd_reset_req_r;
    assign osd_credits_req = osd_credits_req_r;
    assign osd_video_req   = osd_video_req_r;

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

    // OSD-edited machine settings, written by the firmware at 0x2000000C as {index[12:8],
    // value[7:0]} into a small register file; the index order matches settings_ui.c's SET_* enum.
    // A plain value latch: the two-cycle PicoRV32 store just writes the same value twice, so no
    // strobe or edge-detect is needed. Only the settings wired to an output leave this module.
    // The file deliberately survives machine resets (registers power up 0): reset-latched
    // consumers like hgc_mode sample it at reset release, before the restarted firmware can
    // re-push values.
    localparam SET_IDX_CPU_SPEED = 5'd0;
    localparam SET_IDX_BIOS_WR   = 5'd1;
    localparam SET_IDX_OPL2      = 5'd2;
    localparam SET_IDX_BOOST     = 5'd3;
    localparam SET_IDX_SPK_VOL   = 5'd4;
    localparam SET_IDX_COMPOSITE = 5'd7;
    localparam SET_IDX_DISPLAY   = 5'd8;
    localparam SET_IDX_EMS       = 5'd9;
    localparam SET_IDX_EMS_FRAME = 5'd10;
    localparam SET_IDX_A000      = 5'd11;
    localparam SET_IDX_JOY1      = 5'd12;
    localparam SET_IDX_JOY2      = 5'd13;
    localparam SET_IDX_SWAPJOY   = 5'd14;
    localparam SET_IDX_SYNCJOY   = 5'd15;
    localparam SET_IDX_VIDEO_1ST = 5'd16;
    reg [7:0] osd_settings [0:31];
    wire settings_wr = sel_status && cpu_mem_wstrb[0] && cpu_mem_addr[3:2] == 2'd3;
    always @(posedge clk_pico) begin
        if (settings_wr) begin
            osd_settings[cpu_mem_wdata[12:8]] <= cpu_mem_wdata[7:0];
        end
    end
    assign osd_palette   = osd_settings[SET_IDX_DISPLAY][2:0];
    assign osd_cpu_speed = osd_settings[SET_IDX_CPU_SPEED][1:0];
    assign osd_bios_wr   = osd_settings[SET_IDX_BIOS_WR][1:0];
    assign osd_opl2      = osd_settings[SET_IDX_OPL2][1:0];
    assign osd_boost     = osd_settings[SET_IDX_BOOST][1:0];
    assign osd_spk_vol   = osd_settings[SET_IDX_SPK_VOL][1:0];
    assign osd_composite = osd_settings[SET_IDX_COMPOSITE][0];
    assign osd_ems       = osd_settings[SET_IDX_EMS][0];
    assign osd_ems_frame = osd_settings[SET_IDX_EMS_FRAME][1:0];
    assign osd_a000      = osd_settings[SET_IDX_A000][0];
    assign osd_joy1      = osd_settings[SET_IDX_JOY1][1:0];
    assign osd_joy2      = osd_settings[SET_IDX_JOY2][1:0];
    assign osd_swapjoy   = osd_settings[SET_IDX_SWAPJOY][0];
    assign osd_syncjoy   = osd_settings[SET_IDX_SYNCJOY][0];
    assign osd_video_1st = osd_settings[SET_IDX_VIDEO_1ST][0];

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
    // OSD framebuffer: full-screen 640x200 at 4bpp (two pixels per byte), four byte lanes. Each
    // lane is one true-dual-port M10K: Port A (clk_sys) is the GPU's read-modify-write, Port B
    // (clk_pix) is the scanout read, both one-cycle reads (unregistered output over the registered
    // address).
    //
    wire [7:0] pa_q [0:3];   // Port A read data per lane (GPU read-modify-write)
    wire [7:0] fbq [0:3];    // Port B read data per lane (scanout)

    genvar fbl;
    generate
        for (fbl = 0; fbl < 4; fbl = fbl + 1) begin : fb_lane
            altsyncram #(
                .operation_mode ("BIDIR_DUAL_PORT"),
                .width_a        (8),
                .widthad_a      (14),
                .numwords_a     (16384),
                .width_b        (8),
                .widthad_b      (14),
                .numwords_b     (16384),
                .address_reg_b  ("CLOCK1"),
                .outdata_reg_a  ("UNREGISTERED"),
                .outdata_reg_b  ("UNREGISTERED"),
                .lpm_type       ("altsyncram"),
                .intended_device_family ("Cyclone V")
            ) fb (
                .clock0    (clk_sys),
                .address_a (pa_addr),
                .data_a    (pa_wd),
                .wren_a    (pa_we[fbl]),
                .q_a       (pa_q[fbl]),

                .clock1    (clk_pix),
                .address_b (osd_word_addr),
                .data_b    (8'd0),
                .wren_b    (1'b0),
                .q_b       (fbq[fbl]),

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
        end
    endgenerate

    localparam [15:0] OSD_STRIDE = 16'd320; // framebuffer bytes per row (640 / 2)

    //
    // OSD GPU. The CPU no longer writes pixels; it writes drawing commands at 0x4xxxxxxx
    // (clk_pico) and a small FSM renders them into the framebuffer at clk_sys. Command
    // registers:
    //   0x40000000 XY   {y[15:0], x[15:0]}
    //   0x40000004 WH   {h[15:0], w[15:0]}
    //   0x40000008 FILL color[3:0]                  -> fill the XY/WH rectangle
    //   0x40000010 STATUS (read) bit0 = busy
    //   0x40000014 OUTLINE {round, color[3:0]}       -> outline the XY/WH rectangle
    //   0x40000018 CHAR {transp, bg[3:0], fg[3:0], char[7:0]} -> 8x8 glyph at XY
    // A launch write toggles gpu_req; the FSM acknowledges when the command completes.
    // clk_pico is a gated clk_sys pulse, so the parameter registers are stable when the
    // FSM samples them; req/ack cross the domains through two-flop synchronisers.
    //
    localparam [1:0] OP_FILL = 2'd0, OP_OUTLINE = 2'd1, OP_CHAR = 2'd2;

    reg [15:0] gpu_x, gpu_y, gpu_w, gpu_h;
    reg  [3:0] gpu_color;             // FILL/OUTLINE colour, or CHAR foreground
    reg  [3:0] gpu_bg;                // CHAR background (drawn only when not transparent)
    reg  [7:0] gpu_char;              // CHAR glyph index
    reg  [1:0] gpu_op;
    reg        gpu_round;             // OUTLINE: omit the four corner pixels (1px-rounded look)
    reg        gpu_transp;            // CHAR: leave background pixels untouched
    reg        gpu_req;
    // A PicoRV32 store holds the bus for two clk_pico cycles, so a raw write select asserts
    // twice. Committing on cpu_mem_ready (asserted only on the single accept cycle) fires each
    // write once; the launch toggle is edge-detected on top of that so it can never cancel
    // itself, which would leave req == ack, busy stuck low, and any command issued mid-draw
    // dropped. FILL, OUTLINE and CHAR are launches.
    wire gpu_cmd_wr = sel_fb && cpu_mem_wstrb[0] && cpu_mem_ready;
    wire gpu_launch = gpu_cmd_wr && (cpu_mem_addr[4:2] == 3'd2 || cpu_mem_addr[4:2] == 3'd5 ||
                                     cpu_mem_addr[4:2] == 3'd6);
    reg  gpu_launch_d;
    always @(posedge clk_pico) begin
        if (reset) begin
            gpu_req      <= 1'b0;
            gpu_launch_d <= 1'b0;
        end else begin
            gpu_launch_d <= gpu_launch;
            if (gpu_cmd_wr) begin
                case (cpu_mem_addr[4:2])
                    3'd0: begin gpu_x <= cpu_mem_wdata[15:0]; gpu_y <= cpu_mem_wdata[31:16]; end
                    3'd1: begin gpu_w <= cpu_mem_wdata[15:0]; gpu_h <= cpu_mem_wdata[31:16]; end
                    3'd2: begin gpu_color <= cpu_mem_wdata[3:0]; gpu_op <= OP_FILL; end
                    3'd5: begin
                        gpu_color <= cpu_mem_wdata[3:0];
                        gpu_round <= cpu_mem_wdata[4];
                        gpu_op    <= OP_OUTLINE;
                    end
                    3'd6: begin
                        gpu_char   <= cpu_mem_wdata[7:0];
                        gpu_color  <= cpu_mem_wdata[11:8];
                        gpu_bg     <= cpu_mem_wdata[15:12];
                        gpu_transp <= cpu_mem_wdata[16];
                        gpu_op     <= OP_CHAR;
                    end
                    default: ;
                endcase
            end
            if (gpu_launch && !gpu_launch_d) gpu_req <= ~gpu_req; // one toggle per command
        end
    end

    // The command hand-off crosses clocks: gpu_req (clk_pico) is synchronised into clk_sys for
    // the FSM, and the FSM's gpu_ack (clk_sys) is synchronised back so busy = req != ack reads
    // in the CPU's own domain. Each side toggles only its own bit.
    reg gpu_ack;                        // toggled by the FSM (clk_sys)
    reg gpu_ack_s1, gpu_ack_s2;         // gpu_ack -> clk_pico
    always @(posedge clk_pico) begin
        if (reset) {gpu_ack_s2, gpu_ack_s1} <= 2'b00;
        else       {gpu_ack_s2, gpu_ack_s1} <= {gpu_ack_s1, gpu_ack};
    end
    wire [31:0] gpu_status = {31'd0, gpu_req != gpu_ack_s2};

    reg gpu_req_s1, gpu_req_s2;         // gpu_req -> clk_sys
    always @(posedge clk_sys) begin
        if (reset) {gpu_req_s2, gpu_req_s1} <= 2'b00;
        else       {gpu_req_s2, gpu_req_s1} <= {gpu_req_s1, gpu_req};
    end

    //
    // Drawing FSM (clk_sys). Each pixel is one nibble, so the byte is read, the nibble
    // replaced, and written back: GS_RD issues the read, GS_WR writes the modified byte and
    // steps to the next pixel. FILL, OUTLINE and CHAR all walk a rectangle row by row (CHAR a
    // fixed 8x8 cell); OUTLINE writes only the edge pixels and CHAR only the pixels its glyph
    // lights, so each costs a fill of its bounding box. The byte address is an accumulator (row
    // base plus x/2) so there is no per-pixel multiply. A FILL byte that lies fully inside the
    // span is written as one solid byte covering two pixels, so an aligned fill costs one
    // read-write pair per byte instead of one per pixel.
    //
    localparam GS_IDLE = 2'd0, GS_RD = 2'd1, GS_WR = 2'd2;
    reg  [1:0] gs;
    reg [15:0] beg_x, cur_x, end_x, beg_y, cur_y, end_y;
    reg [15:0] row_base, baddr;
    reg        nib;
    reg  [3:0] draw_col, gs_bg;
    reg        gs_outline, gs_round, gs_char, gs_transp;
    reg  [7:0] gs_glyph;
    reg  [2:0] gx, gy;                // glyph-local column/row within the 8x8 cell

    // OSD font ROM: 256 glyphs x 8 rows, one 8-pixel row bitmap per byte (bit 7 = leftmost).
    reg [7:0] font_rom [0:2047];
    initial $readmemh("../firmware/font/font_8x8.vh", font_rom);
    reg [7:0] font_q;                 // current glyph row, registered like the framebuffer read

    wire [1:0]  cur_lane = baddr[1:0];
    wire [7:0]  cur_byte = pa_q[cur_lane];   // Port A read of the current lane
    // CHAR paints a glyph's lit pixels in the foreground colour and, when not transparent, the
    // rest in the background; FILL and OUTLINE paint their single colour.
    wire       font_bit = font_q[3'd7 - gx];
    wire [3:0] draw_nib = gs_char ? (font_bit ? draw_col : gs_bg) : draw_col;
    wire [7:0]  cur_byte_mod = nib ? {cur_byte[7:4], draw_nib} : {draw_nib, cur_byte[3:0]};
    wire [13:0] pa_addr = baddr[15:2];
    // A FILL byte fully inside the span (byte-aligned, so this nibble and the next are both
    // filled) is written as one solid byte, both pixels at once. OUTLINE, CHAR and a FILL's
    // ragged first/last nibble take the per-nibble read-modify-write path.
    wire fill_byte = !gs_outline && !gs_char && (nib == 1'b0) && (cur_x < end_x);
    // What each op writes at the current pixel: OUTLINE only the rectangle edges (a rounded
    // outline drops the four corners); CHAR only lit pixels unless it is opaque; FILL every one.
    wire on_edge   = (cur_x == beg_x) || (cur_x == end_x) || (cur_y == beg_y) || (cur_y == end_y);
    wire at_corner = (cur_x == beg_x || cur_x == end_x) && (cur_y == beg_y || cur_y == end_y);
    wire draw_px   = gs_char    ? (font_bit || !gs_transp)
                   : gs_outline ? (on_edge && !(gs_round && at_corner))
                   :              1'b1;
    wire  [3:0] pa_we   = (gs == GS_WR && draw_px) ? (4'd1 << cur_lane) : 4'd0;
    wire  [7:0] pa_wd   = fill_byte ? {draw_col, draw_col} : cur_byte_mod;

    // Font ROM read, clk_sys, registered one cycle to match the framebuffer Port A read latency so
    // the glyph row and cur_byte arrive together.
    always @(posedge clk_sys) begin
        font_q <= font_rom[{gs_glyph, gy}];
    end

    always @(posedge clk_sys) begin
        if (reset) begin
            gs      <= GS_IDLE;
            gpu_ack <= 1'b0;
        end else begin
            case (gs)
                GS_IDLE:
                    if (gpu_req_s2 != gpu_ack) begin
                        draw_col   <= gpu_color;
                        gs_bg      <= gpu_bg;
                        gs_outline <= (gpu_op == OP_OUTLINE);
                        gs_round   <= gpu_round;
                        gs_char    <= (gpu_op == OP_CHAR);
                        gs_transp  <= gpu_transp;
                        gs_glyph   <= gpu_char;
                        gx         <= 3'd0;
                        gy         <= 3'd0;
                        beg_x      <= gpu_x;
                        cur_x      <= gpu_x;
                        beg_y      <= gpu_y;
                        cur_y      <= gpu_y;
                        end_x      <= (gpu_op == OP_CHAR) ? (gpu_x + 16'd7) : (gpu_x + gpu_w - 16'd1);
                        end_y      <= (gpu_op == OP_CHAR) ? (gpu_y + 16'd7) : (gpu_y + gpu_h - 16'd1);
                        row_base   <= gpu_y * OSD_STRIDE;
                        baddr      <= gpu_y * OSD_STRIDE + {1'b0, gpu_x[15:1]};
                        nib        <= gpu_x[0];
                        gs         <= GS_RD;
                    end
                GS_RD: gs <= GS_WR;
                GS_WR:
                    if (fill_byte ? (cur_x + 16'd1 >= end_x) : (cur_x >= end_x)) begin
                        if (cur_y >= end_y) begin
                            gpu_ack <= ~gpu_ack;
                            gs      <= GS_IDLE;
                        end else begin
                            cur_y    <= cur_y + 16'd1;
                            row_base <= row_base + OSD_STRIDE;
                            cur_x    <= beg_x;
                            baddr    <= row_base + OSD_STRIDE + {1'b0, beg_x[15:1]};
                            nib      <= beg_x[0];
                            gx       <= 3'd0;
                            gy       <= gy + 3'd1;
                            gs       <= GS_RD;
                        end
                    end else if (fill_byte) begin
                        cur_x <= cur_x + 16'd2;         // solid byte covers two pixels
                        baddr <= baddr + 16'd1;
                        gs    <= GS_RD;
                    end else begin
                        cur_x <= cur_x + 16'd1;
                        if (nib) baddr <= baddr + 16'd1;
                        nib   <= ~nib;
                        gx    <= gx + 3'd1;
                        gs    <= GS_RD;
                    end
            endcase
        end
    end

    // Display area: the full 640x200 active raster, drawn 1:1. Overlays position themselves by
    // where the firmware draws them, so the readout starts at the top-left of the raster.
    localparam [9:0] OSD_W = 10'd640;
    localparam [9:0] OSD_H = 10'd200;

    wire osd_in_bounds = (osd_hcnt < OSD_W) && (osd_vcnt < OSD_H);

    // Stride 320 bytes/row, so the row offset is a constant multiply.
    wire  [9:0] osd_x = osd_hcnt;                                           // 0..639
    wire  [9:0] osd_y = osd_vcnt;                                           // 0..199
    wire [15:0] osd_byte_addr = osd_y[7:0] * 16'd320 + {7'd0, osd_x[9:1]};  // y*320 + x/2
    wire [13:0] osd_word_addr = osd_byte_addr[15:2];

    // Port B scanout is the altsyncram's clk_pix side (one-cycle read); the lane/nibble/area
    // selectors are pipelined one stage to match it.
    reg [1:0] osd_lane_r;
    reg       osd_nib_r;
    reg       osd_in_area_r;
    always @(posedge clk_pix) begin
        osd_lane_r    <= osd_byte_addr[1:0];
        osd_nib_r     <= osd_x[0];
        osd_in_area_r <= osd_in_bounds;
    end

    wire [7:0] osd_byte = fbq[osd_lane_r];

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
            32'h2000_0000: cpu_mem_rdata = {6'd0, osd_open_req, credits_active, start_fn, select_fn, cont1_key};
            32'h3???_????: cpu_mem_rdata = fdd_rdata;
            32'h4???_????: cpu_mem_rdata = gpu_status;
            default:       cpu_mem_rdata = 32'd0;
        endcase
    end

endmodule
