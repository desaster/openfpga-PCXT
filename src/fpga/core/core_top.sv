//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

`ifndef SYSTEM_VARIANT_TANDY
`define SYSTEM_VARIANT_TANDY 0
`endif
`ifndef ROM_VARIANT_TANDY
`define ROM_VARIANT_TANDY `SYSTEM_VARIANT_TANDY
`endif
`ifndef ROM_IS_TANDY
`define ROM_IS_TANDY `ROM_VARIANT_TANDY
`endif
`ifndef CONF_STR_SYSTEM
`define CONF_STR_SYSTEM (`SYSTEM_VARIANT_TANDY ? "Tandy1000;UART115200:115200;" : "PCXT;UART115200:115200;")
`endif
`ifndef ENABLE_TANDY_VIDEO
`define ENABLE_TANDY_VIDEO 0
`endif
`ifndef ENABLE_TANDY_AUDIO
`define ENABLE_TANDY_AUDIO 0
`endif
`ifndef ENABLE_TANDY_KBD
`define ENABLE_TANDY_KBD 0
`endif
`ifndef ENABLE_A000_UMB
`define ENABLE_A000_UMB 0
`endif
`ifndef ENABLE_CGA
`define ENABLE_CGA 1
`endif
`ifndef ENABLE_HGC
`define ENABLE_HGC 0
`endif
`ifndef ENABLE_OPL2
`define ENABLE_OPL2 0
`endif
`ifndef ENABLE_CMS
`define ENABLE_CMS 0
`endif
`ifndef ENABLE_EMS
`define ENABLE_EMS 0
`endif

module core_top (

    //
    // physical connections
    //

    // clock inputs, 74.25 MHz (not phase aligned; treat as async domains)
    input  wire         clk_74a,
    input  wire         clk_74b,

    // cartridge interface (unused)
    inout  wire [7:0]   cart_tran_bank2,
    output wire         cart_tran_bank2_dir,
    inout  wire [7:0]   cart_tran_bank3,
    output wire         cart_tran_bank3_dir,
    inout  wire [7:0]   cart_tran_bank1,
    output wire         cart_tran_bank1_dir,
    inout  wire [7:4]   cart_tran_bank0,
    output wire         cart_tran_bank0_dir,
    inout  wire         cart_tran_pin30,
    output wire         cart_tran_pin30_dir,
    output wire         cart_pin30_pwroff_reset,
    inout  wire         cart_tran_pin31,
    output wire         cart_tran_pin31_dir,

    // infrared
    input  wire         port_ir_rx,
    output wire         port_ir_tx,
    output wire         port_ir_rx_disable,

    // GBA link port
    inout  wire         port_tran_si,
    output wire         port_tran_si_dir,
    inout  wire         port_tran_so,
    output wire         port_tran_so_dir,
    inout  wire         port_tran_sck,
    output wire         port_tran_sck_dir,
    inout  wire         port_tran_sd,
    output wire         port_tran_sd_dir,

    // cellular PSRAM 0 and 1 (unused)
    output wire [21:16] cram0_a,
    inout  wire [15:0]  cram0_dq,
    input  wire         cram0_wait,
    output wire         cram0_clk,
    output wire         cram0_adv_n,
    output wire         cram0_cre,
    output wire         cram0_ce0_n,
    output wire         cram0_ce1_n,
    output wire         cram0_oe_n,
    output wire         cram0_we_n,
    output wire         cram0_ub_n,
    output wire         cram0_lb_n,
    output wire [21:16] cram1_a,
    inout  wire [15:0]  cram1_dq,
    input  wire         cram1_wait,
    output wire         cram1_clk,
    output wire         cram1_adv_n,
    output wire         cram1_cre,
    output wire         cram1_ce0_n,
    output wire         cram1_ce1_n,
    output wire         cram1_oe_n,
    output wire         cram1_we_n,
    output wire         cram1_ub_n,
    output wire         cram1_lb_n,

    // SDRAM, 16-bit: the PC's main memory + BIOS live here
    output wire [12:0]  dram_a,
    output wire [1:0]   dram_ba,
    inout  wire [15:0]  dram_dq,
    output wire [1:0]   dram_dqm,
    output wire         dram_clk,
    output wire         dram_cke,
    output wire         dram_ras_n,
    output wire         dram_cas_n,
    output wire         dram_we_n,

    // SRAM (unused)
    output wire [16:0]  sram_a,
    inout  wire [15:0]  sram_dq,
    output wire         sram_oe_n,
    output wire         sram_we_n,
    output wire         sram_ub_n,
    output wire         sram_lb_n,

    // vblank from dock
    input  wire         vblank,

    // debug UART + solderable user pads
    output wire         dbg_tx,
    input  wire         dbg_rx,
    output wire         user1,
    input  wire         user2,

    // RFU I2C + PLL feed
    inout  wire         aux_sda,
    output wire         aux_scl,
    output wire         vpll_feed,

    //
    // logical connections
    //

    // video + audio output to the scaler
    output wire [23:0]  video_rgb,
    output wire         video_rgb_clock,
    output wire         video_rgb_clock_90,
    output wire         video_de,
    output wire         video_skip,
    output wire         video_vs,
    output wire         video_hs,

    output wire         audio_mclk,
    input  wire         audio_adc,
    output wire         audio_dac,
    output wire         audio_lrck,

    // bridge bus (synchronous to clk_74a)
    output wire         bridge_endian_little,
    input  wire [31:0]  bridge_addr,
    input  wire         bridge_rd,
    output reg  [31:0]  bridge_rd_data,
    input  wire         bridge_wr,
    input  wire [31:0]  bridge_wr_data,

    // controller data (4 players)
    input  wire [15:0]  cont1_key,
    input  wire [15:0]  cont2_key,
    input  wire [15:0]  cont3_key,
    input  wire [15:0]  cont4_key,
    input  wire [31:0]  cont1_joy,
    input  wire [31:0]  cont2_joy,
    input  wire [31:0]  cont3_joy,
    input  wire [31:0]  cont4_joy,
    input  wire [15:0]  cont1_trig,
    input  wire [15:0]  cont2_trig,
    input  wire [15:0]  cont3_trig,
    input  wire [15:0]  cont4_trig
);

    //
    // Unused Pocket physical interfaces, tied to safe states.
    // (SDRAM/dram_*, video_*, audio_* are driven by the core below.)
    //

    // IR off, receiver disabled to save power
    assign port_ir_tx              = 0;
    assign port_ir_rx_disable      = 1;

    assign bridge_endian_little    = 0;

    // cartridge level translators (dir 0:IN 1:OUT), unused
    assign cart_tran_bank3         = 8'hzz;
    assign cart_tran_bank3_dir     = 1'b0;
    assign cart_tran_bank2         = 8'hzz;
    assign cart_tran_bank2_dir     = 1'b0;
    assign cart_tran_bank1         = 8'hzz;
    assign cart_tran_bank1_dir     = 1'b0;
    assign cart_tran_bank0         = 4'hf;
    assign cart_tran_bank0_dir     = 1'b1;
    assign cart_tran_pin30         = 1'b0;
    assign cart_tran_pin30_dir     = 1'bz;
    assign cart_pin30_pwroff_reset = 1'b0;
    assign cart_tran_pin31         = 1'bz;
    assign cart_tran_pin31_dir     = 1'b0;

    // GBA link port: input only
    assign port_tran_so            = 1'bz;
    assign port_tran_so_dir        = 1'b0;
    assign port_tran_si            = 1'bz;
    assign port_tran_si_dir        = 1'b0;
    assign port_tran_sck           = 1'bz;
    assign port_tran_sck_dir       = 1'b0;
    assign port_tran_sd            = 1'bz;
    assign port_tran_sd_dir        = 1'b0;

    // cellular PSRAM: unused
    assign cram0_a                 = 'h0;
    assign cram0_dq                = {16{1'bZ}};
    assign cram0_clk               = 0;
    assign cram0_adv_n             = 1;
    assign cram0_cre               = 0;
    assign cram0_ce0_n             = 1;
    assign cram0_ce1_n             = 1;
    assign cram0_oe_n              = 1;
    assign cram0_we_n              = 1;
    assign cram0_ub_n              = 1;
    assign cram0_lb_n              = 1;
    assign cram1_a                 = 'h0;
    assign cram1_dq                = {16{1'bZ}};
    assign cram1_clk               = 0;
    assign cram1_adv_n             = 1;
    assign cram1_cre               = 0;
    assign cram1_ce0_n             = 1;
    assign cram1_ce1_n             = 1;
    assign cram1_oe_n              = 1;
    assign cram1_we_n              = 1;
    assign cram1_ub_n              = 1;
    assign cram1_lb_n              = 1;

    // SRAM: unused
    assign sram_a                  = 'h0;
    assign sram_dq                 = {16{1'bZ}};
    assign sram_oe_n               = 1;
    assign sram_we_n               = 1;
    assign sram_ub_n               = 1;
    assign sram_lb_n               = 1;

    assign dbg_tx                  = 1'bZ;
    assign user1                   = 1'bZ;
    assign aux_scl                 = 1'bZ;
    assign vpll_feed               = 1'bZ;

    // Bridge reads: the command / data-table window (0xF8xxxxxx) reads back from
    // core_bridge_cmd; the softcore bridge RAM (0x6xxxxxxx) reads back for dataslot
    // writes; everything else returns 0.
    //
    // The APF captures bridge_rd_data before it pulses bridge_rd, so the RAM read-back
    // is registered on bridge_rd; read combinationally it would lead the address by
    // one word. core_bridge_cmd already registers its own read. The capture is gated to
    // the 0x6xxxxxxx window so a command-window read cannot overwrite the buffered word.
    wire [31:0] cmd_bridge_rd_data;
    wire [31:0] softcpu_bridge_rd_data;
    reg  [31:0] softcpu_rd_data_buf;
    always @(posedge clk_74a) begin
        if (bridge_rd && bridge_addr[31:28] == 4'h6)
            softcpu_rd_data_buf <= softcpu_bridge_rd_data;
    end
    always @(*) begin
        casex (bridge_addr)
            32'hF8xxxxxx: bridge_rd_data = cmd_bridge_rd_data;
            32'h6xxxxxxx: bridge_rd_data = softcpu_rd_data_buf;
            default:      bridge_rd_data = 32'd0;
        endcase
    end

    wire forced_scandoubler;
    wire [1:0] buttons;
    // Config word: a constant of fixed Pocket defaults. The user-changeable options are not
    // taken from here - they come from the settings bank (osd_*) and the interact regs (*_cfg)
    // below and are consumed directly; only the fixed status[...] reads remain.
    // NB: CGA/EMS/A000 UMB/OPL2 being "on" is contingent on the ENABLE_* macros in
    // ap_core.qsf; the `ifndef fallbacks at the top of this file default them off.
    // The qsf is the source of truth for the feature-enable set.
    wire [63:0] status = 64'h0000_0000_0000_0080;
    wire [7:0]  xtctl;

    // Keyboard: parallel Set-2 byte handshake into CHIPSET
    wire  [7:0] kb_byte;
    wire        kb_valid;
    wire        kb_ready;

    // Mouse: serial-mouse byte stream into CHIPSET's COM1
    wire        mouse_rd;
    wire        mouse_rts_n;

    wire        ioctl_download;
    wire  [7:0] ioctl_index;
    wire        ioctl_wr;
    wire [24:0] ioctl_addr;
    wire [15:0] ioctl_data;
    reg         ioctl_wait;

    wire [13:0] joy0, joy1;
    wire [15:0] joya0, joya1;

    // Controller-button config (interact menu), latched in clk_74a and synced into
    // clk_chipset below. key_* = per-face-button Set-2 scancode; gamepad_mode selects
    // what the pad drives: mapped keys, the game port, or the serial mouse.
    wire [7:0]  key_a, key_b, key_x, key_y;
    wire [1:0]  gamepad_mode;
    wire        gamepad  = (gamepad_mode == 2'd1);
    wire        mousepad = (gamepad_mode == 2'd2);
    // Button Select/Start config: 0xF1=Settings, 0xF2=Pause/Credits, 0xF3=CGA/HGC toggle,
    // other = Set-2 key. Split into an OSD function id for the softcore and a key scancode
    // (0 for the functions) for the keyboard.
    wire [7:0]  select_cfg, start_cfg;
    wire [3:0]  select_fn  = (select_cfg == 8'hF1) ? 4'd1 : (select_cfg == 8'hF2) ? 4'd2 :
                             (select_cfg == 8'hF3) ? 4'd3 : 4'd0;
    wire [3:0]  start_fn   = (start_cfg  == 8'hF1) ? 4'd1 : (start_cfg  == 8'hF2) ? 4'd2 :
                             (start_cfg  == 8'hF3) ? 4'd3 : 4'd0;
    wire [7:0]  select_key = (select_cfg < 8'hF0) ? select_cfg : 8'h00;
    wire [7:0]  start_key  = (start_cfg  < 8'hF0) ? start_cfg  : 8'h00;
    wire [15:0] cont1_key_chip;
    wire [15:0] cont2_key_chip;
    wire [31:0] cont1_joy_chip, cont2_joy_chip;

    // Game-port options from the settings OSD: [4]=Sync-to-CPU turbo timing, [3:2]=Joystick 2,
    // [1:0]=Joystick 1; each 2-bit field is 0=Analog, 1=Digital, 2=Disabled.
    wire [1:0]  joy1_cfg, joy2_cfg;
    wire        swapjoy_cfg, syncjoy_cfg;
    wire [4:0]  joy_opts = {syncjoy_cfg, joy2_cfg, joy1_cfg};

    wire composite_cfg;   // CGA composite colour decode (settings bank, 0x7C)
    wire cga_gfx_cfg, hgc_gfx_cfg;   // CGA/Hercules Graphics I/O enables (settings bank; 0 = Yes)
    wire composite = composite_cfg | xtctl[0];
    wire [1:0] scale = status[2:1];
    wire a000h = `ENABLE_A000_UMB ? (a000_en_cfg & ~xtctl[6]) : 1'b0;
    wire [2:0] vsync_width_osd = status[56:54];  // 0=Auto (use register), 1-7=override
    wire [2:0] hsync_width_osd = status[59:57];  // 0=Auto, 1-7=fixed width (Nx16 pixel clocks)

    reg [1:0]   scale_video_ff;
    reg         hgc_mode_video_ff;
    reg         cga_hw;
    wire        video_scandoubler_en = (scale_video_ff > 0) || forced_scandoubler;
    wire        cga_scandouble_en = video_scandoubler_en;
    reg         hercules_hw;

    wire VGA_VBlank_border;
    wire std_hsyncwidth;
    wire pause_core_chipset;
    wire swap_video;

    always @(posedge clk_chipset)
    begin
        scale_video_ff          <= scale;
        cga_hw                  <= `ENABLE_CGA ? (`ENABLE_HGC ? (~cga_gfx_cfg | tandy_video_mode) : 1'b1) : 1'b0;
        hercules_hw             <= `ENABLE_HGC ? (`ENABLE_CGA ? ~hgc_gfx_cfg : 1'b1) : 1'b0;
    end

    always @(posedge clk_chipset)
        hgc_mode_video_ff       <= `ENABLE_HGC ? hgc_mode : 1'b0;

    //
    // Config + input stubs for the CHIPSET signals the Pocket doesn't drive.
    //
    assign forced_scandoubler = 1'b0;
    assign buttons            = 2'b00;

    // Keyboard driven by pocket_keyboard, mouse by pocket_mouse (both
    // instantiated below, near CHIPSET).
    // Pocket controllers -> game-port inputs. Digital bits: [5]=fire2 [4]=fire1 [3]=up [2]=down
    // [1]=left [0]=right, from cont key bits [0]=up [1]=down [2]=left [3]=right [4]=A [5]=B.
    wire [13:0] cont1_dig = {8'd0, cont1_key_chip[5], cont1_key_chip[4],
                                   cont1_key_chip[0], cont1_key_chip[1],
                                   cont1_key_chip[2], cont1_key_chip[3]};
    wire [13:0] cont2_dig = {8'd0, cont2_key_chip[5], cont2_key_chip[4],
                                   cont2_key_chip[0], cont2_key_chip[1],
                                   cont2_key_chip[2], cont2_key_chip[3]};
    // Left stick -> module analog. The Pocket sends unsigned axes centred on 0x80; the port wants
    // signed centred on 0, so flip the top bit. An analog-less pad reports all-zero on every axis,
    // which the guard passes through as centre (a raw 0 would otherwise convert to full deflection).
    wire [15:0] cont1_ana = (cont1_joy_chip == 32'd0) ? 16'd0
                          : {cont1_joy_chip[15:8] ^ 8'h80, cont1_joy_chip[7:0] ^ 8'h80};
    wire [15:0] cont2_ana = (cont2_joy_chip == 32'd0) ? 16'd0
                          : {cont2_joy_chip[15:8] ^ 8'h80, cont2_joy_chip[7:0] ^ 8'h80};
    // Controller 1 reaches the port only in Gamepad Mode (else its buttons type keys); controller 2
    // is always player 2. Both idle while an OSD panel is open, and a Disabled port sends nothing.
    wire        p1_on = gamepad && !osd_active && (joy1_cfg != 2'd2);
    wire        p2_on = !osd_active && (joy2_cfg != 2'd2);
    assign joy0  = p1_on ? cont1_dig : 14'd0;
    assign joy1  = p2_on ? cont2_dig : 14'd0;
    assign joya0 = p1_on ? cont1_ana : 16'd0;
    assign joya1 = p2_on ? cont2_ana : 16'd0;

    // ROM load: data_loader + FIFO + copier drive ioctl_* in the ROM-LOAD
    // section below; the reused BIOS FSM consumes them.

    // Disk management bus, mastered by the disk softcore (u_softcpu, below).
    wire [15:0] mgmt_din;              // CHIPSET readdata -> softcore
    wire [15:0] mgmt_dout;             // softcore -> CHIPSET write data
    wire [15:0] mgmt_addr;             // softcore -> CHIPSET address
    wire        mgmt_rd;               // softcore -> CHIPSET read strobe
    wire        mgmt_wr;               // softcore -> CHIPSET write strobe
    wire  [7:0] mgmt_req;              // [7:6] fdd request, [2:0] ide0 (from CHIPSET)
    assign mgmt_req[5:3] = 3'b000;

    //
    ///////////////////////   CLOCKS   /////////////////////////////
    //

    wire pll_locked;

    wire clk_100;
    wire clk_28_636;
    wire clk_32_514;
    reg clk_14_318 = 1'b0;
    wire clk_cpu;
    logic cpu_ce_posedge;
    logic cpu_ce_negedge;
    logic peripheral_ce;
    wire clk_chipset;

    localparam [27:0] cur_rate = 28'd50000000;

    wire clk_sdram_ph;
    wire clk_pix_cga;
    wire clk_pix_cga_90;
    wire clk_pix_hgc;
    wire clk_pix_hgc_90;
    wire clk_pix;
    wire clk_pix_90;
    wire pll_video_locked;
    wire pll_video_hgc_locked;

    // System PLL: 50 MHz (chipset + SDRAM ctrl), 100 MHz (CPU), 50 MHz@ps (dram_clk).
    pll pll
    (
        .refclk   (clk_74a),
        .rst      (1'b0),
        .outclk_0 (clk_chipset),
        .outclk_1 (clk_100),
        .outclk_2 (clk_sdram_ph),
        .locked   (pll_locked)
    );

    // CGA video PLL: 28.636 MHz (CGA dot clock), 14.318 MHz pixel + 90-deg sibling.
    pll_video pll_video
    (
        .refclk   (clk_74a),
        .rst      (1'b0),
        .outclk_0 (clk_28_636),
        .outclk_1 (clk_pix_cga),
        .outclk_2 (clk_pix_cga_90),
        .locked   (pll_video_locked)
    );

    // Hercules video PLL: 32.514 MHz (HGC dot clock x2), 16.257 MHz pixel + 90-deg
    // sibling. Referenced from clk_74b: the clk_74a pin reaches only the two
    // bottom-edge fractional-PLL sites, and pll / pll_video occupy those. Absent
    // the card, the tie-offs free the PLL site and fold the RESET lock term.
    generate if (`ENABLE_HGC) begin : gen_pll_video_hgc
    pll_video_hgc pll_video_hgc
    (
        .refclk   (clk_74b),
        .rst      (1'b0),
        .outclk_0 (clk_32_514),
        .outclk_1 (clk_pix_hgc),
        .outclk_2 (clk_pix_hgc_90),
        .locked   (pll_video_hgc_locked)
    );
    end else begin : gen_pll_video_hgc
    assign clk_32_514           = 1'b0;
    assign clk_pix_hgc          = 1'b0;
    assign clk_pix_hgc_90       = 1'b0;
    assign pll_video_hgc_locked = 1'b1;
    end endgenerate

    // The video back-end (palette tint -> credits -> OSD -> output regs and the
    // scaler's video_rgb_clock) runs on whichever pixel pair matches the displayed
    // card; the two card domains themselves never switch. swap_video (the keyboard
    // module's follower of the displayed-card select) drives this sequencer: blank
    // the output, flip both clock muxes mid-window, un-blank once the scaler has
    // seen frames of the new timing.
    wire swap_video_chip;
    synch_3 s_swap_video (swap_video, swap_video_chip, clk_chipset);
    reg         pix_sel   = 1'b0;   // 0 = CGA pixel pair, 1 = HGC pixel pair
    reg         vid_blank = 1'b0;   // forces DE low across the clock switch
    reg  [21:0] pix_switch_cnt = 22'd0;
    localparam  PIX_SWITCH_CYCLES = 22'd4000000;   // 80 ms: ~2 frames each side of the flip
    always @(posedge clk_chipset) begin
        if (pix_switch_cnt != 22'd0) begin
            pix_switch_cnt <= pix_switch_cnt - 22'd1;
            if (pix_switch_cnt == (PIX_SWITCH_CYCLES >> 1))
                pix_sel <= swap_video_chip;
            if (pix_switch_cnt == 22'd1)
                vid_blank <= 1'b0;
        end else if (swap_video_chip != pix_sel) begin
            vid_blank      <= 1'b1;
            pix_switch_cnt <= PIX_SWITCH_CYCLES;
        end
    end

    cyclonev_clkselect u_pixclk_sw
    (
        .clkselect ({1'b1, pix_sel}),
        .inclk     ({clk_pix_hgc, clk_pix_cga, 2'b00}),
        .outclk    (clk_pix)
    );
    cyclonev_clkselect u_pixclk90_sw
    (
        .clkselect ({1'b1, pix_sel}),
        .inclk     ({clk_pix_hgc_90, clk_pix_cga_90, 2'b00}),
        .outclk    (clk_pix_90)
    );

    // Global power-on reset until all PLLs lock.
    wire RESET = ~pll_locked | ~pll_video_locked | ~pll_video_hgc_locked;
    // ROM-load reset hold: keep the machine in reset while APF streams a slot,
    // and from power-on until the first load completes, so the CPU never runs
    // without a BIOS. The BIOS write path is on the separate reset_sdram, which
    // stays up. Driven in the ROM-load glue below.
    wire        is_downloading;      // APF slot load active (clk_chipset)
    wire        load_active;         // is_downloading OR the FIFO still draining
    reg         bios_ever_loaded = 1'b0;

    // Interact-menu "Reset PC" action (interact.json): the Pocket writes 0x50 once
    // when the user selects it. Stretch that single clk_74a write into a level, sync
    // it to the chipset clock, and fold it into the guest reset so the machine
    // re-POSTs and the disk softcore re-mounts the current floppy images.
    reg [19:0] interact_reset_delay = 20'd0;
    // Interact-menu "Extra Options" action: the Pocket writes 0x54 once; the same single-write
    // stretch, synced to the softcore (which owns the OSD) so it opens the settings panel. The
    // guaranteed opener if Button Select has been remapped away from Settings.
    reg [19:0] osd_open_delay = 20'd0;
    // Interact-menu settings (interact.json list variables), each latched write-only
    // from its own bridge address, then synch_3'd into the core clock and consumed
    // directly by the machine below.
    reg  [1:0] wp_cfg_74a        = 2'd0;   // floppy write-protect {B:, A:}
    reg        splash_cfg_74a    = 1'b1;   // boot splash enable (default on)
    reg  [7:0] key_a_74a         = 8'h14;  // A default: L-Ctrl (Set-2 scancode)
    reg  [7:0] key_b_74a         = 8'h11;  // B default: L-Alt
    reg  [7:0] key_x_74a         = 8'h29;  // X default: Space
    reg  [7:0] key_y_74a         = 8'h5A;  // Y default: Enter
    reg  [1:0] gamepad_74a       = 2'd0;   // 0 = keyboard, 1 = joystick (game port), 2 = mouse
    reg  [7:0] select_cfg_74a    = 8'hF1;  // Button Select: 0xF1 = Settings (default)
    reg  [7:0] start_cfg_74a     = 8'hF2;  // Button Start: 0xF2 = Pause/Credits (default)
    reg        credits_active_74a = 1'b0;  // credits showing: set by the menu action, cleared by any button
    // Pad button words refresh from an unvalidated ~1 ms poll and can bounce; a
    // single bad poll would false-edge every consumer. Publish a new word only after
    // several polls agree. Analog joy words are level-read and pass through raw.
    reg [15:0] cont1_key_s = 16'd0;        // settled button words, all consumers below
    reg [15:0] cont2_key_s = 16'd0;
    reg [15:0] key1_cand   = 16'd0;
    reg [15:0] key2_cand   = 16'd0;
    reg [17:0] key_stable  = 18'd0;        // 2^18 clk_74a cycles = 3.5 ms
    always @(posedge clk_74a) begin
        if (cont1_key != key1_cand || cont2_key != key2_cand) begin
            key1_cand  <= cont1_key;
            key2_cand  <= cont2_key;
            key_stable <= 18'd0;
        end else if (!(&key_stable))
            key_stable <= key_stable + 18'd1;
        else begin
            cont1_key_s <= key1_cand;
            cont2_key_s <= key2_cand;
        end
    end
    wire       any_btn_74a;                // any Pocket controller-1 button, synced to this domain
    synch_3 s_anybtn (|cont1_key_s, any_btn_74a, clk_74a);
    wire       osd_reset_req_74a;          // OSD Reset PC request, synced from the softcore
    synch_3 s_osd_reset_74a (osd_reset_req, osd_reset_req_74a, clk_74a);
    wire       osd_credits_req_74a;        // OSD Show Credits request, synced from the softcore
    synch_3 s_osd_credits_74a (osd_credits_req, osd_credits_req_74a, clk_74a);
    reg        any_btn_74a_d = 1'b0;
    reg        osd_credits_req_74a_d = 1'b0;
    always @(posedge clk_74a) begin
        if (interact_reset_delay != 20'd0)
            interact_reset_delay <= interact_reset_delay - 20'd1;
        if (osd_open_delay != 20'd0)
            osd_open_delay <= osd_open_delay - 20'd1;
        if (bridge_wr) begin
            case (bridge_addr)
                32'h0000_0050: interact_reset_delay <= 20'hFFFFF;  // Reset & Apply
                32'h0000_0054: osd_open_delay       <= 20'hFFFFF;  // Extra Options (open OSD)
                32'h0000_006C: wp_cfg_74a        <= bridge_wr_data[1:0];
                32'h0000_0068: splash_cfg_74a    <= bridge_wr_data[0];
                32'h0000_0080: key_a_74a         <= bridge_wr_data[7:0];
                32'h0000_0084: key_b_74a         <= bridge_wr_data[7:0];
                32'h0000_0088: key_x_74a         <= bridge_wr_data[7:0];
                32'h0000_008C: key_y_74a         <= bridge_wr_data[7:0];
                32'h0000_0090: gamepad_74a       <= bridge_wr_data[1:0];
                32'h0000_0094: select_cfg_74a    <= bridge_wr_data[7:0];
                32'h0000_0098: start_cfg_74a     <= bridge_wr_data[7:0];
            endcase
        end
        if (osd_reset_req_74a)
            interact_reset_delay <= 20'hFFFFF;  // OSD Reset PC reuses the interact reset stretch
        // Show Credits request (from the OSD) and the any-button dismiss are edge-detected: the
        // button that picks Show Credits is still held, so a level dismiss would clear it at once.
        any_btn_74a_d         <= any_btn_74a;
        osd_credits_req_74a_d <= osd_credits_req_74a;
        if (osd_credits_req_74a & ~osd_credits_req_74a_d)
            credits_active_74a <= 1'b1;
        else if (any_btn_74a & ~any_btn_74a_d)
            credits_active_74a <= 1'b0;
    end
    wire       interact_reset;
    wire       osd_open_req;
    wire [1:0] cpu_speed_cfg;
    wire [1:0] bios_wr_cfg;
    wire [1:0] wp_cfg;
    wire [1:0] opl2_cfg;
    wire [1:0] boost_cfg;
    wire [1:0] spk_vol_cfg;
    wire [1:0] stereo_mix_cfg;
    wire       cms_cfg;
    wire       ems_en_cfg;
    wire [1:0] ems_frame_cfg;
    wire       a000_en_cfg;
    wire       video_1st_cfg;
    // The OSD-driven display palette, synced into the clk_pix video domain for the output tint.
    wire [2:0] palette_cfg;
    synch_3              s_interact_reset (|interact_reset_delay, interact_reset, clk_chipset);
    synch_3              s_osd_open       (|osd_open_delay,    osd_open_req,  clk_chipset);
    synch_3 #(.WIDTH(2)) s_cpu_speed_cfg  (osd_cpu_speed,     cpu_speed_cfg, clk_chipset);
    synch_3 #(.WIDTH(2)) s_bios_wr_cfg    (osd_bios_wr,       bios_wr_cfg,   clk_chipset);
    synch_3 #(.WIDTH(2)) s_wp_cfg         (wp_cfg_74a,        wp_cfg,        clk_chipset);
    synch_3 #(.WIDTH(2)) s_opl2_cfg       (osd_opl2,          opl2_cfg,      clk_chipset);
    synch_3 #(.WIDTH(2)) s_boost_cfg      (osd_boost,         boost_cfg,     clk_chipset);
    synch_3 #(.WIDTH(2)) s_spk_vol_cfg    (osd_spk_vol,       spk_vol_cfg,   clk_chipset);
    synch_3 #(.WIDTH(2)) s_stereo_cfg     (osd_stereo,        stereo_mix_cfg, clk_chipset);
    synch_3              s_cms_cfg        (osd_cms,           cms_cfg,       clk_chipset);
    synch_3              s_composite_cfg  (osd_composite,     composite_cfg, clk_chipset);
    synch_3              s_ems_en_cfg     (osd_ems,           ems_en_cfg,    clk_chipset);
    synch_3 #(.WIDTH(2)) s_ems_frame_cfg  (osd_ems_frame,     ems_frame_cfg, clk_chipset);
    synch_3              s_a000_en_cfg    (osd_a000,          a000_en_cfg,   clk_chipset);
    synch_3 #(.WIDTH(2)) s_joy1_cfg       (osd_joy1,          joy1_cfg,      clk_chipset);
    synch_3 #(.WIDTH(2)) s_joy2_cfg       (osd_joy2,          joy2_cfg,      clk_chipset);
    synch_3              s_swapjoy_cfg    (osd_swapjoy,       swapjoy_cfg,   clk_chipset);
    synch_3              s_syncjoy_cfg    (osd_syncjoy,       syncjoy_cfg,   clk_chipset);
    synch_3              s_video_1st_cfg  (osd_video_1st,     video_1st_cfg, clk_chipset);
    synch_3              s_cga_gfx_cfg    (osd_cga_gfx,       cga_gfx_cfg,   clk_chipset);
    synch_3              s_hgc_gfx_cfg    (osd_hgc_gfx,       hgc_gfx_cfg,   clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_a          (key_a_74a,         key_a,         clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_b          (key_b_74a,         key_b,         clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_x          (key_x_74a,         key_x,         clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_y          (key_y_74a,         key_y,         clk_chipset);
    synch_3 #(.WIDTH(2))  s_gamepad       (gamepad_74a,       gamepad_mode,  clk_chipset);
    synch_3 #(.WIDTH(8))  s_select_cfg    (select_cfg_74a,    select_cfg,    clk_chipset);
    synch_3 #(.WIDTH(8))  s_start_cfg     (start_cfg_74a,     start_cfg,     clk_chipset);
    synch_3 #(.WIDTH(16)) s_cont1_chip    (cont1_key_s,       cont1_key_chip, clk_chipset);
    synch_3 #(.WIDTH(16)) s_cont2_chip    (cont2_key_s,       cont2_key_chip, clk_chipset);
    synch_3 #(.WIDTH(32)) s_cont1_joy     (cont1_joy,         cont1_joy_chip, clk_chipset);
    synch_3 #(.WIDTH(32)) s_cont2_joy     (cont2_joy,         cont2_joy_chip, clk_chipset);
    synch_3 #(.WIDTH(3)) s_palette_cfg    (osd_palette,       palette_cfg,   clk_pix);
    wire credits_mode_pix;
    wire credits_mode_chip;
    synch_3 s_credits_pix  (credits_active_74a, credits_mode_pix,  clk_pix);
    synch_3 s_credits_chip (credits_active_74a, credits_mode_chip, clk_chipset);
    wire pause_core = pause_core_chipset | credits_mode_chip;

    wire reset_wire = RESET | status[0] | load_active | ~bios_ever_loaded | interact_reset
                    | splashscreen_sync2 | splash_reset_hold | splash_pending_sync2;
    wire reset_sdram_wire = RESET;

    //
    //////////////////   APF bridge command interface   ////////////////
    //
    // core_bridge_cmd handles APF host<->core commands (status, dataslot
    // request/complete, data table) on the clk_74a bridge domain and drives the
    // command read window (see the bridge_rd_data mux above). Savestate / RTC /
    // target-dataslot / on-screen-notify are unused here and tied off; the
    // dataslot request/complete outputs feed the ROM-load download glue.

    wire        reset_n;   // APF-driven core reset (bridge domain)

    // Status handshake, synchronized into the clk_74a bridge domain.
    wire pll_locked_74a;
    synch_3 s_pll_lock (~RESET, pll_locked_74a, clk_74a);
    wire status_boot_done  = pll_locked_74a;
    wire status_setup_done = pll_locked_74a;
    wire status_running    = reset_n;

    // Gate APF write-requests (ROM streaming) until SDRAM init completes.
    wire initilized_sdram_74a;
    synch_3 s_sdram_init (initilized_sdram, initilized_sdram_74a, clk_74a);

    wire        dataslot_requestread;
    wire [15:0] dataslot_requestread_id;
    wire        dataslot_requestwrite;
    wire [15:0] dataslot_requestwrite_id;
    wire [31:0] dataslot_requestwrite_size;
    wire        dataslot_update;
    wire [15:0] dataslot_update_id;
    wire [31:0] dataslot_update_size;
    wire        dataslot_allcomplete;
    wire        osnotify_inmenu;

    // Target-dataslot: the disk softcore initiates host reads of floppy images.
    wire        target_dataslot_read;
    wire        target_dataslot_write;
    wire [15:0] target_dataslot_id;
    wire [31:0] target_dataslot_slotoffset;
    wire [31:0] target_dataslot_bridgeaddr;
    wire [31:0] target_dataslot_length;
    wire        target_dataslot_ack;
    wire        target_dataslot_done;
    wire  [2:0] target_dataslot_err;

    // Data table (dataslot ID/size), two words per slot index, also written by APF at
    // load. Rotate: redeclare the Settings size (word 13; absent on first boot, and a
    // 0-size slot never flushes) and scan the hard-disk sizes (words 9/11; a persisted
    // image appears only here, never as a dataslot update). Reads land two cycles
    // after the address.
    reg  [2:0]  datatable_phase = 3'd0;
    reg  [9:0]  datatable_addr  = 10'd13;
    reg         datatable_wren  = 1'b0;
    reg  [31:0] datatable_data  = 32'd64;
    wire [31:0] datatable_q;
    reg  [31:0] hdd0_slot_bytes_74a = 32'd0;
    reg  [31:0] hdd1_slot_bytes_74a = 32'd0;
    always @(posedge clk_74a) begin
        datatable_phase <= datatable_phase + 3'd1;
        datatable_wren  <= 1'b0;
        case (datatable_phase)
            3'd0: datatable_addr <= 10'd9;      // IDE 0-0 size word (index 4*2+1)
            3'd3: begin
                hdd0_slot_bytes_74a <= datatable_q;
                datatable_addr      <= 10'd11;  // IDE 0-1 size word (index 5*2+1)
            end
            3'd6: begin
                hdd1_slot_bytes_74a <= datatable_q;
                datatable_addr      <= 10'd13;  // Settings size word (index 6*2+1)
                datatable_wren      <= 1'b1;
            end
        endcase
    end

    core_bridge_cmd icb (
        .clk                       (clk_74a),
        .reset_n                   (reset_n),
        .bridge_endian_little      (bridge_endian_little),
        .bridge_addr               (bridge_addr),
        .bridge_rd                 (bridge_rd),
        .bridge_rd_data            (cmd_bridge_rd_data),
        .bridge_wr                 (bridge_wr),
        .bridge_wr_data            (bridge_wr_data),

        .status_boot_done          (status_boot_done),
        .status_setup_done         (status_setup_done),
        .status_running            (status_running),

        .dataslot_requestread      (dataslot_requestread),
        .dataslot_requestread_id   (dataslot_requestread_id),
        .dataslot_requestread_ack  (1'b1),
        .dataslot_requestread_ok   (1'b1),

        .dataslot_requestwrite     (dataslot_requestwrite),
        .dataslot_requestwrite_id  (dataslot_requestwrite_id),
        .dataslot_requestwrite_size(dataslot_requestwrite_size),
        .dataslot_requestwrite_ack (initilized_sdram_74a),
        .dataslot_requestwrite_ok  (1'b1),

        .dataslot_update           (dataslot_update),
        .dataslot_update_id        (dataslot_update_id),
        .dataslot_update_size      (dataslot_update_size),

        .dataslot_allcomplete      (dataslot_allcomplete),

        .rtc_epoch_seconds         (),
        .rtc_date_bcd              (),
        .rtc_time_bcd              (),
        .rtc_valid                 (),

        .savestate_supported       (1'b0),
        .savestate_addr            (32'd0),
        .savestate_size            (32'd0),
        .savestate_maxloadsize     (32'd0),

        .osnotify_inmenu           (osnotify_inmenu),

        .savestate_start           (),
        .savestate_start_ack       (1'b0),
        .savestate_start_busy      (1'b0),
        .savestate_start_ok        (1'b0),
        .savestate_start_err       (1'b0),

        .savestate_load            (),
        .savestate_load_ack        (1'b0),
        .savestate_load_busy       (1'b0),
        .savestate_load_ok         (1'b0),
        .savestate_load_err        (1'b0),

        .target_dataslot_read      (target_dataslot_read),
        .target_dataslot_write     (target_dataslot_write),
        .target_dataslot_ack       (target_dataslot_ack),
        .target_dataslot_done      (target_dataslot_done),
        .target_dataslot_err       (target_dataslot_err),
        .target_dataslot_id        (target_dataslot_id),
        .target_dataslot_slotoffset(target_dataslot_slotoffset),
        .target_dataslot_bridgeaddr(target_dataslot_bridgeaddr),
        .target_dataslot_length    (target_dataslot_length),

        .datatable_addr            (datatable_addr),
        .datatable_wren            (datatable_wren),
        .datatable_data            (datatable_data),
        .datatable_q               (datatable_q)
    );

    // ---- Disk softcore ----
    // Services CHIPSET's floppy.v: pulls sectors from a drive's dataslot with
    // core_bridge_cmd's target_dataslot handshake and streams them over the
    // management bus. A floppy image's size is reported once as a dataslot update
    // (bytes); the hard-disk sizes come from the data table scan above. Convert to
    // sectors on the chipset clock and hand them to the firmware.
    // Floppy images are dataslot id 3 (drive 0) and id 4 (drive 1); the hard disks are
    // id 5 (master) and id 6 (slave); id 1 is the main BIOS and id 2 the EC00 option
    // ROM. Keep in step with FDD0_SLOT_ID / FDD1_SLOT_ID / HDD0_SLOT_ID / HDD1_SLOT_ID
    // in the firmware and the slots in data.json.
    reg [31:0] fdd0_slot_bytes_74a = 32'd0;
    reg [31:0] fdd1_slot_bytes_74a = 32'd0;
    always @(posedge clk_74a) begin
        if (dataslot_update && dataslot_update_id == 16'd3)
            fdd0_slot_bytes_74a <= dataslot_update_size;
        if (dataslot_update && dataslot_update_id == 16'd4)
            fdd1_slot_bytes_74a <= dataslot_update_size;
    end

    // A floppy image (re)binds by a dataslot update, which fires even when the new image
    // is the same size as the old one. Toggle a per-drive bit on each bind so the firmware
    // re-runs the mount, whose eject-then-insert makes floppy.v re-assert its media-change
    // line; a same-size swap otherwise leaves the guest reading the directory it cached
    // from the previous disk. dataslot_update is held for several clk_74a cycles per
    // command, so flip on its rising edge only: a level toggle would flip an even number
    // of times across the pulse and cancel.
    reg        fdd0_rebind_74a   = 1'b0;
    reg        fdd1_rebind_74a   = 1'b0;
    reg        dataslot_update_d = 1'b0;
    always @(posedge clk_74a) begin
        dataslot_update_d <= dataslot_update;
        if (dataslot_update && !dataslot_update_d) begin
            if (dataslot_update_id == 16'd3) fdd0_rebind_74a <= ~fdd0_rebind_74a;
            if (dataslot_update_id == 16'd4) fdd1_rebind_74a <= ~fdd1_rebind_74a;
        end
    end

    wire [31:0] fdd0_slot_bytes;
    wire [31:0] fdd1_slot_bytes;
    wire [31:0] hdd0_slot_bytes;
    wire [31:0] hdd1_slot_bytes;
    synch_3 #(.WIDTH(32)) s_fdd0_size (
        .i   (fdd0_slot_bytes_74a),
        .o   (fdd0_slot_bytes),
        .clk (clk_chipset)
    );
    synch_3 #(.WIDTH(32)) s_fdd1_size (
        .i   (fdd1_slot_bytes_74a),
        .o   (fdd1_slot_bytes),
        .clk (clk_chipset)
    );
    synch_3 #(.WIDTH(32)) s_hdd0_size (
        .i   (hdd0_slot_bytes_74a),
        .o   (hdd0_slot_bytes),
        .clk (clk_chipset)
    );
    synch_3 #(.WIDTH(32)) s_hdd1_size (
        .i   (hdd1_slot_bytes_74a),
        .o   (hdd1_slot_bytes),
        .clk (clk_chipset)
    );
    wire [31:0] fdd0_disk_sectors = fdd0_slot_bytes >> 9;   // bytes / 512
    wire [31:0] fdd1_disk_sectors = fdd1_slot_bytes >> 9;   // bytes / 512
    wire [31:0] hdd0_disk_sectors = hdd0_slot_bytes >> 9;   // bytes / 512
    wire [31:0] hdd1_disk_sectors = hdd1_slot_bytes >> 9;   // bytes / 512

    wire fdd0_rebind;
    wire fdd1_rebind;
    synch_3 s_fdd0_rebind (
        .i   (fdd0_rebind_74a),
        .o   (fdd0_rebind),
        .clk (clk_chipset)
    );
    synch_3 s_fdd1_rebind (
        .i   (fdd1_rebind_74a),
        .o   (fdd1_rebind),
        .clk (clk_chipset)
    );

    // OSD overlay interconnect: the raster counters (driven in the video output
    // stage) locate the framebuffer readout; the softcore returns a 4bpp palette
    // index + in-area flag, composited into the picture there.
    reg  [9:0] osd_hcnt = 10'd0;
    reg  [9:0] osd_vcnt = 10'd0;
    wire [9:0] osd_vcnt_sel;         // line index of the presented raster (assigned at the canvas)
    wire [9:0] osd_raster_w;         // presented raster size (assigned at the canvas)
    wire [9:0] osd_raster_h;
    wire [3:0] osd_palette_idx;
    wire       osd_in_area;
    wire       osd_active;
    wire       osd_reset_req;
    wire       osd_credits_req;
    wire       osd_video_req;
    wire [8:0] vkb_key;
    wire       vkb_stb;
    wire [2:0] osd_palette;
    wire [1:0] osd_cpu_speed;
    wire [1:0] osd_bios_wr;
    wire [1:0] osd_opl2;
    wire [1:0] osd_boost;
    wire [1:0] osd_spk_vol;
    wire [1:0] osd_stereo;
    wire       osd_cms;
    wire       osd_composite;
    wire       osd_ems;
    wire [1:0] osd_ems_frame;
    wire       osd_a000;
    wire [1:0] osd_joy1;
    wire [1:0] osd_joy2;
    wire       osd_swapjoy;
    wire       osd_syncjoy;
    wire       osd_video_1st;
    wire       osd_cga_gfx;
    wire       osd_hgc_gfx;

    // High from power-on until the softcore's first reset request; lets the firmware
    // re-apply reset-latched settings once, after the saved values are pushed.
    reg cold_boot = 1'b1;
    always @(posedge clk_chipset)
        if (osd_reset_req) cold_boot <= 1'b0;

    softcpu_subsystem u_softcpu (
        .clk_sys                    (clk_chipset),
        .clk_74a                    (clk_74a),
        .reset                      (reset),

        .fdd_request                (mgmt_req[7:6]),
        .ide0_request               (mgmt_req[2:0]),
        .fdd0_disk_size             (fdd0_disk_sectors),
        .fdd1_disk_size             (fdd1_disk_sectors),
        .hdd0_disk_size             (hdd0_disk_sectors),
        .hdd1_disk_size             (hdd1_disk_sectors),
        .fdd0_rebind                (fdd0_rebind),
        .fdd1_rebind                (fdd1_rebind),

        .mgmt_addr                  (mgmt_addr),
        .mgmt_dout                  (mgmt_dout),
        .mgmt_wr                    (mgmt_wr),
        .mgmt_rd                    (mgmt_rd),
        .mgmt_din                   (mgmt_din),

        .bridge_wr                  (bridge_wr),
        .bridge_addr                (bridge_addr),
        .bridge_wr_data             (bridge_wr_data),

        .target_dataslot_read       (target_dataslot_read),
        .target_dataslot_write      (target_dataslot_write),
        .target_dataslot_id         (target_dataslot_id),
        .target_dataslot_slotoffset (target_dataslot_slotoffset),
        .target_dataslot_bridgeaddr (target_dataslot_bridgeaddr),
        .target_dataslot_length     (target_dataslot_length),
        .target_dataslot_ack        (target_dataslot_ack),
        .target_dataslot_done       (target_dataslot_done),
        .target_dataslot_err        (target_dataslot_err),

        .bridge_rd_data_out         (softcpu_bridge_rd_data),

        .clk_pix                    (clk_pix),
        .osd_hcnt                   (osd_hcnt),
        .osd_vcnt                   (osd_vcnt_sel),
        .osd_palette_idx            (osd_palette_idx),
        .osd_in_area                (osd_in_area),

        .cont1_key                  (cont1_key_chip),
        .select_fn                  (select_fn),
        .start_fn                   (start_fn),
        .credits_active             (credits_mode_chip),
        .osd_open_req               (osd_open_req),
        .raster_w                   (osd_raster_w),
        .raster_h                   (osd_raster_h),
        .cold_boot                  (cold_boot),
        .osd_active                 (osd_active),
        .osd_reset_req              (osd_reset_req),
        .osd_credits_req            (osd_credits_req),
        .osd_video_req              (osd_video_req),
        .vkb_key                    (vkb_key),
        .vkb_stb                    (vkb_stb),
        .osd_palette                (osd_palette),
        .osd_cpu_speed              (osd_cpu_speed),
        .osd_bios_wr                (osd_bios_wr),
        .osd_opl2                   (osd_opl2),
        .osd_boost                  (osd_boost),
        .osd_spk_vol                (osd_spk_vol),
        .osd_stereo                 (osd_stereo),
        .osd_cms                    (osd_cms),
        .osd_composite              (osd_composite),
        .osd_ems                    (osd_ems),
        .osd_ems_frame              (osd_ems_frame),
        .osd_a000                   (osd_a000),
        .osd_joy1                   (osd_joy1),
        .osd_joy2                   (osd_joy2),
        .osd_swapjoy                (osd_swapjoy),
        .osd_syncjoy                (osd_syncjoy),
        .osd_video_1st              (osd_video_1st),
        .osd_cga_gfx                (osd_cga_gfx),
        .osd_hgc_gfx                (osd_hgc_gfx)
    );

    // ---- ROM-load download tracking ----
    // dataslot_requestwrite marks the start of an APF->core slot stream;
    // dataslot_allcomplete marks the end. Track it on the bridge clock, then
    // sync into the chipset domain for the loader and the reset hold above.
    reg         is_downloading_74a = 1'b0;
    reg  [15:0] download_id_74a = 16'd0;
    always @(posedge clk_74a) begin
        if (dataslot_requestwrite) begin
            is_downloading_74a <= 1'b1;
            download_id_74a    <= dataslot_requestwrite_id;
        end
        else if (dataslot_allcomplete)
            is_downloading_74a <= 1'b0;
    end
    synch_3 s_isdl (is_downloading_74a, is_downloading, clk_chipset);
    wire [15:0] download_id;
    synch_3 #(.WIDTH(16)) s_dlid (download_id_74a, download_id, clk_chipset);

    reg load_active_d = 1'b0;
    always @(posedge clk_chipset) begin
        load_active_d <= load_active;
        if (load_active_d & ~load_active)   // APF done AND the FIFO fully drained
            bios_ever_loaded <= 1'b1;
    end

    //////////////////////////////////////////////////////////////////

    always @(posedge clk_28_636)
        clk_14_318 <= ~clk_14_318;   // 14.318 MHz toggle for splash / UART timing

    //////////////////////////////////////////////////////////////////

    logic  biu_done;
    logic  [7:0] clock_cycle_counter_division_ratio;
    logic  [7:0] clock_cycle_counter_decrement_value;
    logic        shift_read_timing;
    logic  [1:0] ram_read_wait_cycle;
    logic  [1:0] ram_write_wait_cycle;
    logic        cycle_accrate;
    logic  [1:0] clk_select;
    wire   [1:0] clk_select_next = ((xtctl[3:2] == 2'b00) && ~xtctl[7]) ? cpu_speed_cfg :
                                   (xtctl[7] ? 2'b11 : xtctl[3:2] - 2'b01);

    always @(posedge clk_chipset, posedge reset)
    begin
        if (reset)
            clk_select <= 2'b00;
        else if (biu_done)
            clk_select <= clk_select_next;
    end

    XT_CE_Generator u_XT_CE_Generator
    (
        .clock                              (clk_chipset),
        .reset                              (reset),
        .clk_select_load                    (biu_done),
        .clk_select                         (clk_select_next),
        .cpu_clk_pin                        (clk_cpu),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .peripheral_ce                      (peripheral_ce),
        .cycle_accrate                      (cycle_accrate),
        .clock_cycle_counter_division_ratio (clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing                  (shift_read_timing),
        .ram_read_wait_cycle                (ram_read_wait_cycle),
        .ram_write_wait_cycle               (ram_write_wait_cycle)
    );
    //////////////////////////////////////////////////////////////////

    logic reset = 1'b1;
    logic [15:0] reset_count = 16'h0000;
    logic reset_sdram = 1'b1;
    logic [15:0] reset_sdram_count = 16'h0000;

    always @(posedge clk_chipset, posedge reset_wire)
    begin
        if (reset_wire)
        begin
            reset <= 1'b1;
            reset_count <= 16'h0000;
        end
        else if (reset)
        begin
            if (reset_count != 16'hffff)
            begin
                reset <= 1'b1;
                reset_count <= reset_count + 16'h0001;
            end
            else
            begin
                reset <= 1'b0;
                reset_count <= reset_count;
            end
        end
        else
        begin
            reset <= 1'b0;
            reset_count <= reset_count;
        end
    end

    logic reset_cpu_ff = 1'b1;
    logic reset_cpu = 1'b1;
    logic [15:0] reset_cpu_count = 16'h0000;

    always @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
            reset_cpu_ff <= 1'b1;
        else
            reset_cpu_ff <= reset;
    end

    localparam tandy_video_mode = `ENABLE_TANDY_VIDEO;
    reg hgc_mode = 0;

    always @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
        begin
            hgc_mode <= `ENABLE_HGC ? (`ENABLE_CGA ? video_1st_cfg : 1'b1) : 1'b0;
            reset_cpu <= 1'b1;
            reset_cpu_count <= 16'h0000;
        end
        else if (reset_cpu)
        begin
            reset_cpu <= reset_cpu_ff;
            reset_cpu_count <= 16'h0000;
        end
        else
        begin
            if (reset_cpu_count != 16'h002A)
            begin
                reset_cpu <= reset_cpu_ff;
                reset_cpu_count <= reset_cpu_count + 16'h0001;
            end
            else
            begin
                reset_cpu <= 1'b0;
                reset_cpu_count <= reset_cpu_count;
            end
        end
    end

    always @(posedge clk_chipset, posedge reset_sdram_wire)
    begin
        if (reset_sdram_wire)
        begin
            reset_sdram <= 1'b1;
            reset_sdram_count <= 16'h0000;
        end
        else if (reset_sdram)
        begin
            if (reset_sdram_count != 16'hffff)
            begin
                reset_sdram <= 1'b1;
                reset_sdram_count <= reset_sdram_count + 16'h0001;
            end
            else
            begin
                reset_sdram <= 1'b0;
                reset_sdram_count <= reset_sdram_count;
            end
        end
        else
        begin
            reset_sdram <= 1'b0;
            reset_sdram_count <= reset_sdram_count;
        end
    end

    //
    /////////////////////   ROM-LOAD (APF -> BIOS FSM)   ////////////////////
    //
    // APF streams the BIOS slot into the 0x1xxxxxxx bridge window; data_loader
    // turns that into 16-bit (addr,data) writes on clk_chipset. APF can't be
    // backpressured, so a FIFO captures every write; the copier then feeds the
    // reused BIOS-load FSM as an ioctl stream, honoring its ioctl_wait.
    wire        dl_wr;
    wire [27:0] dl_addr;
    wire [15:0] dl_data;

    data_loader #(
        .ADDRESS_MASK_UPPER_4 (4'h1),
        .ADDRESS_SIZE         (28),
        .OUTPUT_WORD_SIZE     (2),
        .WRITE_MEM_CLOCK_DELAY(16)
    ) rom_data_loader (
        .clk_74a             (clk_74a),
        .clk_memory          (clk_chipset),
        .bridge_wr           (bridge_wr),
        .bridge_endian_little(bridge_endian_little),
        .bridge_addr         (bridge_addr),
        .bridge_wr_data      (bridge_wr_data),
        .write_en            (dl_wr),
        .write_addr          (dl_addr),
        .write_data          (dl_data)
    );

    // Decoupling FIFO (same clk_chipset domain), entry = {xtide, addr[24:0], data[15:0]}.
    // The slot tag rides in each entry so a following stream cannot retag a draining
    // tail. 256 deep: generous headroom; the handshake loader keeps pace so it stays
    // shallow. An overflow would drop a write (and fail POST), but cannot happen
    // here: the consumer keeps pace and load_active holds reset until it drains.
    localparam RLF_AW = 8;
    reg  [41:0]     romfifo [0:(1<<RLF_AW)-1];
    reg  [RLF_AW:0] rlf_wptr = 0;
    reg  [RLF_AW:0] rlf_rptr = 0;
    wire            rlf_empty = (rlf_wptr == rlf_rptr);
    wire            rlf_full  = (rlf_wptr[RLF_AW-1:0] == rlf_rptr[RLF_AW-1:0])
                              && (rlf_wptr[RLF_AW] != rlf_rptr[RLF_AW]);
    wire [41:0]     rlf_head  = romfifo[rlf_rptr[RLF_AW-1:0]];
    reg             rlf_pop;

    // Drain gate: keep loading until APF is done AND the FIFO is emptied, so the
    // tail of the ROM cannot be lost if allcomplete races ahead of the last write.
    assign load_active = is_downloading | ~rlf_empty;

    always @(posedge clk_chipset) begin
        if (dl_wr && ~rlf_full) begin
            romfifo[rlf_wptr[RLF_AW-1:0]] <= {download_id == 16'd2, dl_addr[24:0], dl_data};
            rlf_wptr <= rlf_wptr + 1'b1;
        end
        if (rlf_pop && ~rlf_empty)
            rlf_rptr <= rlf_rptr + 1'b1;
    end

    // Copier: present the FIFO head to the BIOS FSM as ioctl, honoring ioctl_wait.
    assign ioctl_download = load_active;
    assign ioctl_index    = rlf_head[41] ? 8'd2 : 8'd0;  // EC00 (XT-IDE)->2, BIOS->0
    assign ioctl_addr     = rlf_head[40:16];
    assign ioctl_data     = rlf_head[15:0];
    reg ioctl_wr_r = 1'b0;
    assign ioctl_wr = ioctl_wr_r;

    always @(posedge clk_chipset) begin
        rlf_pop <= 1'b0;
        if (~load_active)
            ioctl_wr_r <= 1'b0;
        else if (ioctl_wr_r) begin
            if (ioctl_wait) begin        // FSM latched the presented word
                ioctl_wr_r <= 1'b0;
                rlf_pop    <= 1'b1;
            end
        end
        else if (~ioctl_wait && ~rlf_empty)
            ioctl_wr_r <= 1'b1;
    end

    //
    ///////////////////////   BIOS LOADER   ////////////////////////////
    //

    reg [4:0]  bios_load_state = 4'h0;
    reg [1:0]  bios_protect_flag;
    reg        bios_access_request;
    reg [19:0] bios_access_address;
    reg [15:0] bios_write_data;
    reg        bios_write_n;
    reg [7:0]  bios_write_wait_cnt;
    reg        bios_write_byte_cnt;
    reg        tandy_bios_write;
    wire select_pcxt  = (ioctl_index[5:0] == 0) && (ioctl_addr[24:16] == 9'b000000000);
    wire select_tandy = `ROM_IS_TANDY ? (ioctl_index[5:0] == 1) && (ioctl_addr[24:16] == 9'b000000000) : 1'b0;
    wire select_xtide = ioctl_index == 2;

    wire [19:0] bios_access_address_wire = select_pcxt  ? { 4'b1111, ioctl_addr[15:0]} :
         select_tandy ? { 4'b1111, ioctl_addr[15:0]} :
         select_xtide ? { 6'b111011, ioctl_addr[13:0]} :
         20'hFFFFF;

    wire bios_load_n = ~(ioctl_download & (select_pcxt | select_tandy | select_xtide));

    always @(posedge clk_chipset, posedge reset_sdram)
    begin
        if (reset_sdram)
        begin
            bios_protect_flag   <= 2'b11;
            bios_access_request <= 1'b0;
            bios_access_address <= 20'hFFFFF;
            bios_write_data     <= 16'hFFFF;
            bios_write_n        <= 1'b1;
            bios_write_wait_cnt <= 'h0;
            bios_write_byte_cnt <= 1'h0;
            tandy_bios_write    <= 1'b0;
            ioctl_wait          <= 1'b1;
            bios_load_state     <= 4'h00;
        end
        else if (~initilized_sdram)
        begin
            bios_protect_flag   <= 2'b11;
            bios_access_request <= 1'b0;
            bios_access_address <= 20'hFFFFF;
            bios_write_data     <= 16'hFFFF;
            bios_write_n        <= 1'b1;
            bios_write_wait_cnt <= 'h0;
            bios_write_byte_cnt <= 1'h0;
            ioctl_wait          <= 1'b1;
            bios_load_state     <= 4'h00;
        end
        else
        begin
            casez (bios_load_state)
                4'h00:
                begin
                    bios_protect_flag   <= ~bios_wr_cfg;  // bios_writable
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= 1'h0;
                    tandy_bios_write    <= 1'b0;
                    if (~ioctl_download)
                    begin
                        bios_access_request <= 1'b0;
                        ioctl_wait          <= 1'b0;
                    end
                    else
                    begin
                        bios_access_request <= 1'b1;
                        ioctl_wait          <= 1'b1;
                    end

                    if ((ioctl_download) && (~processor_ready) && (address_direction))
                        bios_load_state <= 4'h01;
                    else
                        bios_load_state <= 4'h00;
                end
                4'h01:
                begin
                    bios_protect_flag   <= 2'b00;
                    bios_access_request <= 1'b1;
                    bios_write_byte_cnt <= 1'h0;
                    tandy_bios_write    <= select_tandy;
                    if (~ioctl_download)
                    begin
                        bios_access_address <= 20'hFFFFF;
                        bios_write_data     <= 16'hFFFF;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b0;
                        bios_load_state     <= 4'h00;
                    end
                    else if ((~ioctl_wr) || (bios_load_n))
                    begin
                        bios_access_address <= 20'hFFFFF;
                        bios_write_data     <= 16'hFFFF;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b0;
                        bios_load_state     <= 4'h01;
                    end
                    else
                    begin
                        bios_access_address <= bios_access_address_wire;
                        bios_write_data     <= ioctl_data;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b1;
                        bios_load_state     <= 4'h02;
                    end
                end
                4'h02:
                begin
                    bios_protect_flag   <= 2'b00;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address;
                    bios_write_data     <= bios_write_data;
                    bios_write_byte_cnt <= bios_write_byte_cnt;
                    tandy_bios_write    <= select_tandy;
                    ioctl_wait          <= 1'b1;

                    // Handshake: hold the external write asserted until the RAM
                    // controller reports the access complete (ram_rw_complete), or
                    // a safety timeout (a hang backstop; a normal write completes in
                    // a few cycles and must never reach it, else that byte is lost).
                    if (ram_rw_complete || (bios_write_wait_cnt == 8'd63))
                    begin
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 8'h0;
                        bios_load_state     <= 4'h03;
                    end
                    else
                    begin
                        bios_write_n        <= 1'b0;
                        bios_write_wait_cnt <= bios_write_wait_cnt + 8'h1;
                        bios_load_state     <= 4'h02;
                    end
                end
                4'h03:
                begin
                    bios_protect_flag   <= 2'b00;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address;
                    bios_write_data     <= bios_write_data;
                    bios_write_n        <= 1'b1;
                    bios_write_byte_cnt <= bios_write_byte_cnt;
                    tandy_bios_write    <= 1'b0;
                    ioctl_wait          <= 1'b1;
                    bios_write_wait_cnt <= bios_write_wait_cnt + 8'h1;

                    // Short settle so the RAM controller returns to IDLE (and
                    // ram_rw_complete drops) before the next byte write.
                    if (bios_write_wait_cnt >= 8'd4)
                        bios_load_state     <= 4'h04;
                    else
                        bios_load_state     <= 4'h03;
                end
                4'h04:
                begin
                    bios_protect_flag   <= 2'b00;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address + 'h1;
                    bios_write_data     <= {8'hFF, bios_write_data[15:8]};
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= ~bios_write_byte_cnt;
                    tandy_bios_write    <= 1'b0;
                    ioctl_wait          <= 1'b1;
                    if (bios_write_byte_cnt == 1'b0)
                        bios_load_state     <= 4'h02;
                    else
                        bios_load_state     <= 4'h01;
                end
                default:
                begin
                    bios_protect_flag   <= 2'b11;
                    bios_access_request <= 1'b0;
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= 1'h0;
                    tandy_bios_write    <= 1'b0;
                    ioctl_wait          <= 1'b0;
                    bios_load_state     <= 4'h00;
                end
            endcase
        end
    end


    //////////////////////////////////////////////////////////////////

    //
    // Splash screen
    //
    reg splash_off = 1'b1;
    reg [24:0] splash_cnt = 0;
    reg [3:0] splash_cnt2 = 0;
    reg splashscreen = 1'b0;
    reg splash_pending = 1'b1;
    reg splash_pending_sync1 = 1'b1;
    reg splash_pending_sync2 = 1'b1;
    reg splashscreen_sync1 = 0;
    reg splashscreen_sync2 = 0;
    reg splashscreen_sync_prev = 0;
    reg status0_sync1 = 0;
    reg status0_sync2 = 0;
    reg status0_sync_prev = 0;
    wire status0_clear_pulse = status0_sync2 & ~status0_sync_prev;
    reg splash_reset_hold = 0;
    reg [16:0] splash_reset_cnt = 17'd0;
    localparam [16:0] SPLASH_RESET_HOLD = 17'd131072;
    reg phys_reset_hold = 0;
    reg [23:0] phys_reset_cnt = 24'd0;
    localparam [23:0] PHYS_RESET_HOLD = 24'd2863600;
    wire splash_on_14_cfg;
    wire video_1st_14;
    wire bios_ever_loaded_14;
    synch_3 s_splash_on      (splash_cfg_74a,   splash_on_14_cfg,    clk_14_318);
    synch_3 s_video_1st_14   (osd_video_1st,    video_1st_14,        clk_14_318);
    synch_3 s_bios_loaded_14 (bios_ever_loaded, bios_ever_loaded_14, clk_14_318);
    // The splash draws into CGA VRAM, so a Hercules boot skips it rather than
    // holding the machine on a blank mono screen.
    wire splash_on_14 = splash_on_14_cfg & ~video_1st_14;

    always @ (posedge clk_14_318)
    begin
        splash_off <= ~splash_on_14;
        if (RESET || buttons[1])
        begin
            phys_reset_hold <= 1'b1;
            phys_reset_cnt <= 24'd0;
        end
        else if (phys_reset_hold)
        begin
            if (phys_reset_cnt == PHYS_RESET_HOLD)
                phys_reset_hold <= 1'b0;
            else
                phys_reset_cnt <= phys_reset_cnt + 24'd1;
        end

        if (splash_pending)
        begin
            // Hold until the BIOS has streamed in, then show the splash (or, if it is
            // disabled, release straight to POST).
            if (bios_ever_loaded_14)
            begin
                if (~splash_off)
                begin
                    splashscreen <= 1'b1;
                    splash_cnt <= 0;
                    splash_cnt2 <= 0;
                end
                splash_pending <= 1'b0;
            end
        end
        else if (splashscreen)
        begin
            if (splash_off)
            begin
                splashscreen <= 0;
            end
            else if(splash_cnt2 == 5) // 5 seconds delay
            begin
                splashscreen <= 0;
            end
            else if (splash_cnt == 14318000)
            begin // 1 second at 14.318Mhz
                splash_cnt2 <= splash_cnt2 + 1;
                splash_cnt <= 0;
            end
            else
                splash_cnt <= splash_cnt + 1;
        end

    end

    always @(posedge clk_chipset)
    begin
        splashscreen_sync1 <= splashscreen;
        splashscreen_sync2 <= splashscreen_sync1;
        splashscreen_sync_prev <= splashscreen_sync2;
        splash_pending_sync1 <= splash_pending;
        splash_pending_sync2 <= splash_pending_sync1;
        status0_sync1 <= status[0];
        status0_sync2 <= status0_sync1;
        status0_sync_prev <= status0_sync2;

        if (splashscreen_sync_prev && ~splashscreen_sync2)
        begin
            splash_reset_hold <= 1'b1;
            splash_reset_cnt  <= 17'd0;
        end
        else if (splash_reset_hold)
        begin
            if (splash_reset_cnt == SPLASH_RESET_HOLD)
                splash_reset_hold <= 1'b0;
            else
                splash_reset_cnt <= splash_reset_cnt + 17'd1;
        end
    end

    wire [7:0] data_bus;
    wire INTA_n;
    wire [19:0] cpu_ad_out;
    reg  [19:0] cpu_address;
    wire [7:0] cpu_data_bus;
    wire processor_ready;
    wire interrupt_to_cpu;
    wire address_latch_enable;
    wire address_direction;

    wire lock_n;
    wire [2:0]processor_status;

    wire [3:0]   dma_acknowledge_n;

    logic   [7:0]   port_b_out;
    logic   [7:0]   port_c_in;
    wire    [1:0]   fdd_present;
    reg     [7:0]   sw;

    wire    [5:0]   sw_base;
    wire    [1:0]   sw_floppy;

    assign  sw_base = `ENABLE_HGC ? (hgc_mode ? 6'b111101 : 6'b101101) : 6'b101101;
    assign  sw_floppy = fdd_present[1] ? 2'b01 : 2'b00;
    assign  sw = {sw_floppy, sw_base}; // DIP switches (display type and floppy count)
    assign  port_c_in[3:0] = port_b_out[3] ? sw[7:4] : sw[3:0];

    wire tandy_bios_flag = bios_write_n ? `ROM_IS_TANDY : tandy_bios_write;

    // Displayed card = the boot card XOR the Select-button CGA/HGC toggle. The toggle
    // clears at machine reset, so a fresh POST always shows the 1st Video card.
    reg  video_swap = 1'b0;
    wire osd_video_req_chip;
    synch_3 s_osd_video_req (osd_video_req, osd_video_req_chip, clk_chipset);
    reg  osd_video_req_d = 1'b0;
    always @(posedge clk_chipset) begin
        osd_video_req_d <= osd_video_req_chip;
        if (reset)
            video_swap <= 1'b0;
        else if (osd_video_req_chip & ~osd_video_req_d)
            video_swap <= ~video_swap;
    end

    wire video_output_sel = `ENABLE_HGC ? (hgc_mode_video_ff ^ video_swap) : 1'b0;
    wire enable_hgc_sel = `ENABLE_HGC ? 1'b1 : 1'b0;
    wire [1:0] hgc_rgb_sel = `ENABLE_HGC ? 2'b10 : 2'b00;
    wire hercules_hw_sel = `ENABLE_HGC ? hercules_hw : 1'b0;
    wire ems_enabled_sel = `ENABLE_EMS ? ems_en_cfg : 1'b0;
    wire [1:0] ems_address_sel = `ENABLE_EMS ? ems_frame_cfg : 2'b00;

    always @(posedge clk_chipset)
    begin
        if (address_latch_enable)
            cpu_address <= cpu_ad_out;
        else
            cpu_address <= cpu_address;
    end

    //
    // Keyboard: controller buttons + docked USB keyboard + virtual keyboard ->
    // one Set-2 byte stream handed to CHIPSET's KFPS2KB over kb_byte/kb_valid,
    // paced by kb_ready.
    //
    // Mouse mode consumes the D-pad and A/B; X/Y and Select/Start stay mapped keys.
    wire [15:0] kb_buttons = mousepad ? (cont1_key_s & 16'hFFC0) : cont1_key_s;

    pocket_keyboard u_pocket_keyboard (
        .clk          (clk_chipset),
        .reset        (reset),
        .buttons      (kb_buttons),
        .gamepad      (gamepad),
        .osd_active   (osd_active | credits_mode_chip),
        .vkb_key      (vkb_key),
        .vkb_stb      (vkb_stb),
        .cfg_a        (key_a),
        .cfg_b        (key_b),
        .cfg_x        (key_x),
        .cfg_y        (key_y),
        .cfg_select   (select_key),
        .cfg_start    (start_key),
        .cont3_joy    (cont3_joy),
        .cont3_trig   (cont3_trig),
        .cont3_key    (cont3_key),
        .kb_byte      (kb_byte),
        .kb_valid     (kb_valid),
        .kb_ready     (kb_ready)
    );

    //
    // Mouse: docked USB mouse (cont4_*) -> Microsoft serial mouse byte stream
    // on CHIPSET's COM1, identification paced by its RTS. In mouse mode the
    // pad's D-pad and A/B drive it too, quiet while an overlay is up.
    //
    wire [5:0] mouse_pad = (mousepad && !(osd_active | credits_mode_chip)) ?
                           cont1_key_chip[5:0] : 6'd0;

    pocket_mouse u_pocket_mouse (
        .clk          (clk_chipset),
        .cont4_joy    (cont4_joy),
        .cont4_key    (cont4_key),
        .cont4_trig   (cont4_trig),
        .pad          (mouse_pad),
        .rts_n        (mouse_rts_n),
        .rd           (mouse_rd)
    );

    CHIPSET #(.clk_rate(cur_rate)) u_CHIPSET
	(
		.clock                              (clk_chipset),
		.cpu_ce_posedge                     (cpu_ce_posedge),
		.cpu_ce_negedge                     (cpu_ce_negedge),
		.clk_sys                            (clk_chipset),
		.peripheral_ce                      (peripheral_ce),
		.clk_select                         (clk_select),
		.reset                              (reset_cpu),
		.sdram_reset                        (reset_sdram),
		.cpu_address                        (cpu_address),
		.cpu_data_bus                       (cpu_data_bus),
		.processor_status                   (processor_status),
		.processor_lock_n                   (lock_n),
	//	.processor_transmit_or_receive_n    (processor_transmit_or_receive_n),
		.processor_ready                    (processor_ready),
		.interrupt_to_cpu                   (interrupt_to_cpu),
		.splashscreen                       (splashscreen),
		.status0_clear                      (status0_clear_pulse),
		.std_hsyncwidth                     (std_hsyncwidth),
		.composite                          (composite),
		.video_output                       (video_output_sel),
		.clk_vga_cga                        (clk_28_636),
		.enable_cga                         (`ENABLE_CGA),
		.clk_vga_hgc                        (clk_32_514),
		.enable_hgc                         (enable_hgc_sel),
		.hgc_rgb                            (hgc_rgb_sel),
	//	.de_o                               (VGA_DE),
		.VGA_R                              (r),
		.VGA_G                              (g),
		.VGA_B                              (b),
		.VGA_HSYNC                          (HSync),
		.VGA_VSYNC                          (VSync),
		.VGA_HBlank                         (HBlank),
		.VGA_VBlank                         (VBlank),
		.VGA_VBlank_border                  (VGA_VBlank_border),
	//	.address                            (address),
		.address_ext                        (bios_access_address),
		.ext_access_request                 (bios_access_request),
		.address_direction                  (address_direction),
		.data_bus                           (data_bus),
		.data_bus_ext                       (bios_write_data[7:0]),
	//	.data_bus_direction                 (data_bus_direction),
		.address_latch_enable               (address_latch_enable),
	//  .io_channel_check                   (),
		.io_channel_ready                   (1'b1),
		.interrupt_request                  (0),    // use?	-> It does not seem to be necessary.
	//  .io_read_n                          (io_read_n),
		.io_read_n_ext                      (1'b1),
	//  .io_read_n_direction                (io_read_n_direction),
	//  .io_write_n                         (io_write_n),
		.io_write_n_ext                     (1'b1),
	//  .io_write_n_direction               (io_write_n_direction),
	//  .memory_read_n                      (memory_read_n),
		.memory_read_n_ext                  (1'b1),
	//  .memory_read_n_direction            (memory_read_n_direction),
	//  .memory_write_n                     (memory_write_n),
		.memory_write_n_ext                 (bios_write_n),
	//  .memory_write_n_direction           (memory_write_n_direction),
		.dma_request                        (0),    // use?	-> I don't know if it will ever be necessary, at least not during testing.
		.dma_acknowledge_n                  (dma_acknowledge_n),
	//  .address_enable_n                   (address_enable_n),
	//  .terminal_count_n                   (terminal_count_n)
		.port_b_out                         (port_b_out),
		.port_c_in                          (port_c_in),
		.port_b_in                          (port_b_out),
		.speaker_out                        (speaker_out),
		.kb_byte                            (kb_byte),
		.kb_valid                           (kb_valid),
		.kb_ready                           (kb_ready),
		.uart_rx                            (mouse_rd),
		.uart_rts_n                         (mouse_rts_n),
		.joy_opts                           (joy_opts),           //Joy0-Disabled, Joy0-Type, Joy1-Disabled, Joy1-Type, turbo_sync
		.joy0                               (swapjoy_cfg ? joy1 : joy0),
		.joy1                               (swapjoy_cfg ? joy0 : joy1),
		.joya0                              (swapjoy_cfg ? joya1 : joya0),
		.joya1                              (swapjoy_cfg ? joya0 : joya1),
		.jtopl2_snd_e                       (jtopl2_snd_e),
		.tandy_snd_e                        (tandy_snd_e),
		.opl2_io                            (xtctl[4] ? 2'b10 : opl2_cfg),
		.cms_en                             (cms_cfg),
		.o_cms_l                            (cms_l_snd_e),
		.o_cms_r                            (cms_r_snd_e),
		.tandy_video                        (tandy_video_mode),
		.tandy_bios_flag                    (tandy_bios_flag),
		.tandy_16_gfx                       (tandy_16_gfx),
		.tandy_color_16                     (tandy_color_16),
		.clk_uart                           (clk_uart2_en),
		.uart2_rx                           (uart_rx),
		.uart2_tx                           (uart_tx),
		.uart2_cts_n                        (uart_cts),
		.uart2_dcd_n                        (uart_dcd),
		.uart2_dsr_n                        (uart_dsr),
		.uart2_rts_n                        (uart_rts),
		.uart2_dtr_n                        (uart_dtr),
		.enable_sdram                       (1'b1),
		.initilized_sdram                   (initilized_sdram),
		.sdram_clock                        (SDRAM_CLK),
		.sdram_address                      (SDRAM_A),
		.sdram_cke                          (SDRAM_CKE),
		.sdram_cs                           (SDRAM_nCS),
		.sdram_ras                          (SDRAM_nRAS),
		.sdram_cas                          (SDRAM_nCAS),
		.sdram_we                           (SDRAM_nWE),
		.sdram_ba                           (SDRAM_BA),
		.sdram_dq_in                        (SDRAM_DQ_IN),
		.sdram_dq_out                       (SDRAM_DQ_OUT),
		.sdram_dq_io                        (SDRAM_DQ_IO),
		.sdram_ldqm                         (SDRAM_DQML),
		.sdram_udqm                         (SDRAM_DQMH),
		.ems_enabled                        (ems_enabled_sel),
		.ems_address                        (ems_address_sel),
		.bios_protect_flag                  (bios_protect_flag),
		.use_mmc                            (use_mmc),
		.spi_clk                            (spi_clk),
		.spi_cs                             (spi_cs),
		.spi_mosi                           (spi_mosi),
		.spi_miso                           (spi_miso),
		.mgmt_readdata                      (mgmt_din),
		.mgmt_writedata                     (mgmt_dout),
		.mgmt_address                       (mgmt_addr),
		.mgmt_write                         (mgmt_wr),
		.mgmt_read                          (mgmt_rd),
		.floppy_wp                          (wp_cfg),
		.fdd_present                        (fdd_present),
		.fdd_request                        (mgmt_req[7:6]),
		.ide0_request                       (mgmt_req[2:0]),
		.xtctl                              (xtctl),
		.enable_a000h                       (a000h),
		.wait_count_clk_en                  (cpu_ce_negedge),
		.ram_read_wait_cycle                (ram_read_wait_cycle),
		.ram_write_wait_cycle               (ram_write_wait_cycle),
		.pause_core                         (pause_core_chipset),
		.cga_hw                             (cga_hw),
		.cga_scandouble_en                  (cga_scandouble_en),
		.hercules_hw                        (hercules_hw_sel),
		.swap_video                         (swap_video),
		.crt_h_offset                       (status[49:46]),
		.crt_v_offset                       (status[52:50]),
		.vsync_width_osd                    (vsync_width_osd),
		.hsync_width_osd                    (hsync_width_osd),
		.ram_rw_complete                    (ram_rw_complete)
	);

    // CHIPSET per-access "done" pulse (COMPLETE_RAM_RW); drives the ROM-load FSM.
    wire        ram_rw_complete;

    // ---- SDRAM boundary: chipset controller -> Pocket dram_* pins ----
    // CHIPSET drives these; pass straight through.
    wire        SDRAM_CLK;
    wire        SDRAM_CKE;
    wire [12:0] SDRAM_A;
    wire  [1:0] SDRAM_BA;
    wire        SDRAM_DQML;
    wire        SDRAM_DQMH;
    wire        SDRAM_nCS;
    wire        SDRAM_nCAS;
    wire        SDRAM_nRAS;
    wire        SDRAM_nWE;
    wire [15:0] SDRAM_DQ_IN;
    wire [15:0] SDRAM_DQ_OUT;
    wire        SDRAM_DQ_IO;
    wire        initilized_sdram;

    assign SDRAM_CLK  = clk_chipset;    // controller clock fed into the chipset
    assign dram_clk   = clk_sdram_ph;   // device clock, phase-shifted 50 MHz
    assign dram_cke   = SDRAM_CKE;
    assign dram_a     = SDRAM_A;
    assign dram_ba    = SDRAM_BA;
    assign dram_dqm   = {SDRAM_DQMH, SDRAM_DQML};
    assign dram_ras_n = SDRAM_nRAS;
    assign dram_cas_n = SDRAM_nCAS;
    assign dram_we_n  = SDRAM_nWE;
    // no dram_cs pin on the Pocket; SDRAM_nCS is left unconnected

    assign SDRAM_DQ_IN = dram_dq;
    assign dram_dq     = ~SDRAM_DQ_IO ? SDRAM_DQ_OUT : 16'hZZZZ;

    wire s6_3_mux;
    wire [2:0] SEGMENT;

    i8088 B1 	
	(
		.CORE_CLK(clk_100),
		.CLK(clk_cpu),

		.RESET(reset_cpu),
		.READY(processor_ready && ~pause_core),
		.NMI(1'b0),
		.INTR(interrupt_to_cpu),

		.ad_out(cpu_ad_out),
		.dout(cpu_data_bus),
		.din(data_bus),

		.lock_n(lock_n),
		.s6_3_mux(s6_3_mux),
		.s2_s0_out(processor_status),
		.SEGMENT(SEGMENT),

		.biu_done(biu_done),
		.cycle_accrate(cycle_accrate),
		.clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
		.clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
		.shift_read_timing(shift_read_timing)
	);

    //
    ////////////////////////////  AUDIO  ///////////////////////////////////
    //

    wire [15:0] cms_l_snd_e;
    wire [16:0] cms_l_snd = {cms_l_snd_e[15],cms_l_snd_e};
    wire [15:0] cms_r_snd_e;
    wire [16:0] cms_r_snd = {cms_r_snd_e[15],cms_r_snd_e};
	 
    wire [15:0] jtopl2_snd_e;
    wire [16:0] jtopl2_snd = {jtopl2_snd_e[15], jtopl2_snd_e};
    wire [10:0] tandy_snd_e;
    wire [16:0] tandy_snd = `ENABLE_TANDY_AUDIO ? {{{2{tandy_snd_e[10]}}, {4{tandy_snd_e[10]}}, tandy_snd_e} << status[35:34], 2'b00} : 17'd0;
    wire [16:0] spk_vol =  {2'b00, {3'b000,~speaker_out} << spk_vol_cfg, 11'd0};
    wire        speaker_out;

    localparam [3:0] comp_f1 = 4;
    localparam [3:0] comp_a1 = 2;
    localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
    localparam       comp_b1 = comp_x1 * comp_a1;

    localparam [3:0] comp_f2 = 8;
    localparam [3:0] comp_a2 = 4;
    localparam       comp_x2 = ((32767 * (comp_f2 - 1)) / ((comp_f2 * comp_a2) - 1)) + 1; // +1 to make sure it won't overflow
    localparam       comp_b2 = comp_x2 * comp_a2;

    function [15:0] compr;
        input [15:0] inp;
        reg [15:0] v, v1, v2;
        begin
            v  = inp[15] ? (~inp) + 1'd1 : inp;
            v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
            v2 = (v < comp_x2[15:0]) ? (v * comp_a2) : (((v - comp_x2[15:0])/comp_f2) + comp_b2[15:0]);
            v  = boost_cfg[1] ? v2 : v1;
            compr = inp[15] ? ~(v-1'd1) : v;
        end
    endfunction

    reg [15:0] cmp_l;
    reg [15:0] out_l;
    always @(posedge clk_chipset)
    begin
        reg [16:0] tmp_l;

        tmp_l <= jtopl2_snd + cms_l_snd + tandy_snd + spk_vol;

        // clamp the output
        out_l <= (^tmp_l[16:15]) ? {tmp_l[16], {15{tmp_l[15]}}} : tmp_l[15:0];

        cmp_l <= compr(out_l);
    end

    reg [15:0] cmp_r;
    reg [15:0] out_r;
    always @(posedge clk_chipset)
    begin
        reg [16:0] tmp_r;

        tmp_r <= jtopl2_snd + cms_r_snd + tandy_snd + spk_vol;

        // clamp the output
        out_r <= (^tmp_r[16:15]) ? {tmp_r[16], {15{tmp_r[15]}}} : tmp_r[15:0];

        cmp_r <= compr(out_r);
    end

    // ---- Audio: filter chain + I2S (Pocket audio codec) ----
    // audio_mixer stands in for the MiSTer framework back end: the default
    // anti-aliasing low-pass + DC blocker (the raw mix carries square-wave
    // harmonics past Nyquist), the AUDIO_MIX crossfeed, and the codec clocks.
    wire [15:0] audio_l = pause_core ? 16'd0 : (boost_cfg ? cmp_l : out_l);
    wire [15:0] audio_r = pause_core ? 16'd0 : (boost_cfg ? cmp_r : out_r);

    audio_mixer #(.DW(16), .STEREO(1)) audio_mixer (
        .clk_74b    (clk_74b),
        .clk_audio  (clk_chipset),
        .reset      (1'b0),
        .vol_att    (4'd0),
        .mix        (stereo_mix_cfg),
        .is_signed  (1'b1),
        .core_l     (audio_l),
        .core_r     (audio_r),
        .audio_mclk (audio_mclk),
        .audio_lrck (audio_lrck),
        .audio_dac  (audio_dac)
    );

    //
    ////////////////////////////  UART  ///////////////////////////////////
    //
    // COM1 (serial mouse) and COM2 live inside CHIPSET; their clock enable is generated
    // here. COM2's inputs are tied to the idle/marking level (no external serial wiring
    // on the Pocket).

    logic clk_uart_ff_1;
    logic clk_uart_ff_2;
    logic clk_uart_ff_3;
    logic clk_uart_en;
    logic clk_uart2_en;
    logic [2:0] clk_uart2_counter;

    always @(posedge clk_chipset)
    begin
        clk_uart_ff_1 <= clk_14_318;
        clk_uart_ff_2 <= clk_uart_ff_1;
        clk_uart_ff_3 <= clk_uart_ff_2;
        clk_uart_en   <= ~clk_uart_ff_3 & clk_uart_ff_2;
    end

    always @(posedge clk_chipset)
    begin
        if (clk_uart_en)
        begin
            if (3'd7 != clk_uart2_counter)
            begin
                clk_uart2_counter <= clk_uart2_counter +3'd1;
                clk_uart2_en <= 1'b0;
            end
            else
            begin
                clk_uart2_counter <= 3'd0;
                clk_uart2_en <= 1'b1;
            end
        end
        else
        begin
            clk_uart2_counter <= clk_uart2_counter;
            clk_uart2_en <= 1'b0;
        end
    end

    wire uart_tx, uart_rts, uart_dtr;   // CHIPSET COM2 outputs, no external pins
    wire uart_rx  = 1'b1;
    wire uart_cts = 1'b1;
    wire uart_dsr = 1'b1;
    wire uart_dcd = 1'b1;

    //
    ///////////////////////   MMC     ///////////////////////
    //
    // SPI/MMC storage path unused; the managed-SD ide.v backend is used instead.
    wire [1:0] use_mmc = 2'b00;
    wire spi_clk, spi_cs, spi_mosi;     // CHIPSET outputs, no external pins
    wire spi_miso = 1'b0;

    //
    ///////////////////////   VIDEO   ///////////////////////
    //
    // Lean CGA/HGC -> Pocket scaler: the Pocket scaler does the scaling and filtering.
    // DE/porches follow CHIPSET's CGA blanking as-is; the Hercules raster is reshaped
    // into the fixed canvas below.
    //
    // r/g/b/HSync/VSync/HBlank/VBlank leave CHIPSET on the displayed card's dot-clock
    // domain (clk_28_636 CGA, clk_32_514 HGC). clk_pix is the matching half-rate
    // sibling off the same PLL, phase-aligned and muxed together with it by the
    // switch sequencer above, so it samples them cleanly, one pixel per edge.

    wire        HBlank;
    wire        HSync;
    wire        VBlank;
    wire        VSync;
    wire [5:0]  r, g, b;
    wire        tandy_16_gfx, tandy_color_16;   // CHIPSET Tandy-video outputs (unused)

    // Monochrome-monitor palette (Display setting). palette_cfg 0 = full colour; 1-7
    // tint the pixel by its weighted luma (green/amber/B&W/red/blue/fuchsia/purple).
    // Combinational, so the lean clk_pix output needs no extra pixel clock/enable and
    // adds no latency. r/g/b are 6-bit; widen to 8 for the luma weights.
    wire [7:0]  pr = {r, 2'b00};
    wire [7:0]  pg = {g, 2'b00};
    wire [7:0]  pb = {b, 2'b00};
    wire [15:0] luma16 = pr * 16'd54 + pg * 16'd183 + pb * 16'd18;  // Rec.709 weights <<8
    wire [7:0]  mono   = luma16[15:8];
    wire [7:0]  hmono  = {1'b0, luma16[15:9]};   // mono >> 1
    reg  [7:0]  tr, tg, tb;
    always @(*) begin
        case (palette_cfg)
            3'd1: begin tr = 8'h00;                         tg = (mono < 8'h0F) ? 8'h0F : mono; tb = 8'h01; end
            3'd2: begin tr = (mono < 8'h08) ? 8'h08 : mono; tg = hmono;                         tb = 8'h01; end
            3'd3: begin tr = mono;                          tg = mono;                          tb = mono;  end
            3'd4: begin tr = (mono < 8'h08) ? 8'h08 : mono; tg = 8'h00;                         tb = 8'h01; end
            3'd5: begin tr = 8'h00;                         tg = hmono;                         tb = (mono < 8'h08) ? 8'h08 : mono; end
            3'd6: begin tr = (mono < 8'h08) ? 8'h08 : mono; tg = 8'h00;                         tb = hmono; end
            3'd7: begin tr = hmono;                         tg = 8'h00;                         tb = (mono < 8'h08) ? 8'h08 : mono; end
            default: begin tr = pr; tg = pg; tb = pb; end   // full colour
        endcase
    end

    // Hercules canvas: the guest programs arbitrary 6845 rasters (custom sizes,
    // rows that straddle the hsync edge, modes without vertical blanking), so the
    // display side presents one fixed 720x350 window and pads the rest black,
    // like a fixed-raster monitor. Each line the window runs 720 dots from the
    // guest's active start (a row cannot straddle its own start); each frame it
    // runs 350 lines opening CANVAS_VSKIP lines after the vsync fall (the one
    // vertical event every mode generates). The scaler needs every DE line
    // bit-identical, so vertical state only moves at the end of a line's dot
    // run, never at a line start where a registered value would lag by a dot.
    //
    // CANVAS_VSKIP must equal the scaler's measured frame anchor: it places DE
    // lines by a vsync-anchored line counter, not by arrival, so a window that
    // opens early shows its first lines wrapped to the frame bottom. A wrapped
    // strip along the bottom edge means this constant is off by its height.
    localparam CANVAS_W = 10'd720;
    localparam CANVAS_H = 10'd350;
    localparam CANVAS_VSKIP = 5'd16; // lines from the vsync fall to the window top
    wire hgc_shown_pix;
    synch_3 s_hgc_shown_pix (pix_sel, hgc_shown_pix, clk_pix);
    reg       src_hb_d = 1'b0;
    reg       src_vs_d = 1'b0;
    reg       v_arm    = 1'b0;   // vsync fell; window opens after the skip
    reg [4:0] v_skip   = 5'd0;
    reg [9:0] h_run    = 10'd0;  // dots left in this line's window
    reg [9:0] v_run    = 10'd0;  // lines left in this frame's window
    wire      line_open = src_hb_d & ~HBlank & (h_run == 10'd0);   // guest active start
    always @(posedge clk_pix) begin
        src_hb_d <= HBlank;
        src_vs_d <= VSync;
        if (~VSync & src_vs_d) begin
            v_arm  <= 1'b1;
            v_skip <= 5'd0;
        end
        if (line_open) begin
            h_run <= CANVAS_W - 10'd1;   // this cycle is the window's first dot
        end else if (h_run != 10'd0) begin
            h_run <= h_run - 10'd1;
            if (h_run == 10'd1) begin    // line end: settle v_run for the next line
                if (v_arm) begin
                    if (v_skip == CANVAS_VSKIP - 5'd1) begin
                        v_run <= CANVAS_H;
                        v_arm <= 1'b0;
                    end else begin
                        v_run  <= 10'd0;   // skip lines stay blank
                        v_skip <= v_skip + 5'd1;
                    end
                end else if (v_run != 10'd0) begin
                    v_run <= v_run - 10'd1;
                end
            end
        end
    end
    wire canvas_hb = ~(line_open | (h_run != 10'd0));
    wire canvas_vb = (v_run == 10'd0);

    // Blanking presented to the scaler and overlays: the canvas on Hercules, the
    // source raster on CGA (cga.v already normalizes every CGA mode to 640x200).
    wire vid_hb  = hgc_shown_pix ? canvas_hb : HBlank;
    wire vid_vb  = hgc_shown_pix ? canvas_vb : VBlank;
    // Canvas padding: inside the window but outside the guest's active raster.
    // The window's first line (v_run still at its load value) is sacrificial
    // and forced black: the scaler captures the frame's first DE line
    // unreliably, so no content may depend on it.
    wire vid_pad = hgc_shown_pix & (HBlank | VBlank | (v_run == CANVAS_H));

    wire        credits_hb, credits_vb;
    wire [23:0] credits_rgb;
    wire        credits_rst;
    synch_3 s_credits_rst (RESET, credits_rst, clk_pix);

    jtframe_credits #(
        .PAGES  (4),
        .COLW   (8),
        .BLKPOL (1)
    ) u_credits(
        .rst        ( credits_rst ),
        .clk        ( clk_pix ),
        .pxl_cen    ( 1'b1 ),

        // input image
        .HB         ( vid_hb  ),
        .VB         ( vid_vb ),
        .rgb_in     ( vid_pad ? 24'd0 : {tr, tg, tb} ),   // live picture; the credits dim it behind the scrolling text
        .rotate     ( 2'd0  ),
        .toggle     ( 1'b0  ),
        .fast_scroll( 1'b0  ),
        .border     ( 1'b0 ),

        .vram_din   ( 8'h0  ),
        .vram_dout  (       ),
        .vram_addr  ( 8'h0  ),
        .vram_we    ( 1'b0  ),
        .vram_ctrl  ( 3'b0  ),
        .enable     ( credits_mode_pix ),

        // output image
        .HB_out     ( credits_hb      ),
        .VB_out     ( credits_vb      ),
        .rgb_out    ( credits_rgb )
    );

    // OSD overlay raster counters: osd_hcnt = pixel within the active line; the
    // line index is the canvas countdown when the canvas is shown (offset past
    // the sacrificial first line), else an hblank-fall counter parked at -1 so
    // the first fall, which lands after VBlank ends, counts line 0.
    reg osd_hb_d = 1'b0;
    always @(posedge clk_pix) begin
        osd_hb_d <= vid_hb;
        if (vid_hb)                  osd_hcnt <= 10'd0;
        else                         osd_hcnt <= osd_hcnt + 10'd1;
        if (vid_vb)                  osd_vcnt <= 10'd1023;
        else if (osd_hb_d & ~vid_hb) osd_vcnt <= osd_vcnt + 10'd1;
    end
    assign osd_vcnt_sel = hgc_shown_pix ? (CANVAS_H - 10'd1 - v_run) : osd_vcnt;

    // Presented raster size, read by the softcore to place the overlay window;
    // the canvas reports its 349 usable lines, excluding the sacrificial one.
    assign osd_raster_w = pix_sel ? CANVAS_W : 10'd640;
    assign osd_raster_h = pix_sel ? (CANVAS_H - 10'd1) : 10'd200;

    // Scaler slot (video.json): 0 = CGA 640x200, 1 = the Hercules canvas. The
    // canvas absorbs every guest-programmed HGC geometry, so the slot follows
    // only the displayed card.
    wire [2:0] vid_slot = hgc_shown_pix ? 3'd1 : 3'd0;

    // Framebuffer palette index -> opaque colour; index 0 is transparent and
    // falls through to the picture.
    wire osd_enable;
    synch_3 s_osd_enable_pix (osd_active, osd_enable, clk_pix);
    wire vid_blank_pix;
    synch_3 s_vid_blank_pix (vid_blank, vid_blank_pix, clk_pix);
    wire osd_show = osd_enable & osd_in_area & (osd_palette_idx != 4'd0);
    reg [23:0] osd_color;
    always @(*) begin
        case (osd_palette_idx)
            4'd1:    osd_color = 24'hF1E5D5;   // body
            4'd2:    osd_color = 24'hD5C9B9;   // key face
            4'd3:    osd_color = 24'hB0A58F;   // accent key face
            4'd4:    osd_color = 24'h212421;   // key edge
            4'd5:    osd_color = 24'h101010;   // label
            4'd6:    osd_color = 24'hFFFFFF;   // cursor
            4'd7:    osd_color = 24'h30C030;   // latched
            4'd8:    osd_color = 24'h90FF90;   // latched under cursor
            4'd9:    osd_color = 24'h8C8578;   // disabled (dimmed label)
            default: osd_color = 24'h000000;
        endcase
    end

    reg  [23:0] vid_rgb = 24'd0;
    reg         vid_de  = 1'b0;
    reg         vid_hs  = 1'b0;
    reg         vid_vs  = 1'b0;
    reg         hs_d    = 1'b0;
    reg         vs_d    = 1'b0;

    // The credits overlay registers HB/VB/RGB by one clk_pix; stage HSync/VSync once
    // (hs_d/vs_d) so sync stays aligned with the overlaid pixels. Whenever DE is
    // low the bus carries the end-of-line word naming the scaler slot ([23:13] =
    // slot, function code [2:0] = 0), held through the whole blanking interval:
    // an all-zero blanking bus is itself a slot-0 command and the last word in a
    // frame wins. Its function bits are zero, so it is inert during VS.
    wire vid_de_now = ~(credits_hb | credits_vb) & ~vid_blank_pix;
    always @(posedge clk_pix)
    begin
        hs_d    <= HSync;
        vs_d    <= VSync;
        vid_de  <= vid_de_now;
        vid_rgb <= vid_de_now ? (osd_show ? osd_color : credits_rgb)
                 :              {8'd0, vid_slot, 13'd0};
        vid_hs  <= hs_d;
        vid_vs  <= vs_d;
    end

    assign video_rgb          = vid_rgb;
    assign video_de           = vid_de;
    assign video_hs           = vid_hs;
    assign video_vs           = vid_vs;
    assign video_skip         = 1'b0;
    assign video_rgb_clock    = clk_pix;
    assign video_rgb_clock_90 = clk_pix_90;

endmodule
