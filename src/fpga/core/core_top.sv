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

    //
    // FEATURE CONFIGURATION
    //

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
    // UNUSED PHYSICAL INTERFACES
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

    //
    // CLOCKING
    //

    wire pll_locked;             // system PLL lock

    wire clk_100;                // 100 MHz, i8088 core
    wire clk_28_636;             // CGA dot clock
    wire clk_32_514;             // HGC dot clock (x2)
    wire clk_cpu;                // 8088 pin clock (gated)
    logic cpu_ce_posedge;        // CPU clock-enable, rising
    logic cpu_ce_negedge;        // CPU clock-enable, falling
    logic peripheral_ce;         // peripheral clock-enable
    wire clk_chipset;            // 50 MHz, main domain

    localparam [27:0] cur_rate = 28'd50000000; // chipset clock rate, Hz

    wire clk_sdram_ph;           // SDRAM pin clock, phase-shifted
    wire clk_pix_cga;            // CGA pixel
    wire clk_pix_cga_90;         // CGA pixel, 90 deg
    wire clk_pix_hgc;            // HGC pixel
    wire clk_pix_hgc_90;         // HGC pixel, 90 deg
    wire clk_pix;                // selected pixel, video out
    wire clk_pix_90;             // selected pixel, 90 deg
    wire pll_video_locked;       // CGA PLL lock
    wire pll_video_hgc_locked;   // HGC PLL lock

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
    // sibling. From clk_74b: pll / pll_video already hold both clk_74a PLL sites.
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

    // 14.318 MHz tick (clk_28_636 / 2): clock-enable for the splash timer and the
    // UART baud base.
    reg ce_14_318 = 1'b0;
    always @(posedge clk_28_636)
        ce_14_318 <= ~ce_14_318;

    // CPU clock: XT_CE_Generator derives the 8088 pin clock and its CE strobes;
    // clk_select sets the speed and is reloaded each bus cycle (biu_done).
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

    // COM baud clock-enables: a ce_14_318 edge sampled onto clk_chipset (COM1),
    // divided by 8 for COM2.
    logic clk_uart_ff_1;
    logic clk_uart_ff_2;
    logic clk_uart_ff_3;
    logic clk_uart_en;
    logic clk_uart2_en;
    logic [2:0] clk_uart2_counter;

    always @(posedge clk_chipset)
    begin
        clk_uart_ff_1 <= ce_14_318;
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

    // Pixel-clock switch: video_rgb_clock follows the displayed card's pixel pair.
    // On a card change (swap_video), blank the output, flip both muxes mid-window,
    // then un-blank once the scaler has seen frames of the new timing.
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

    //
    // RESET
    //

    // Global power-on reset until all PLLs lock.
    wire RESET = ~pll_locked | ~pll_video_locked | ~pll_video_hgc_locked;

    // Guest reset terms: PLL lock (RESET), ROM load and the first-BIOS gate,
    // interact/OSD Reset PC, and the splash holds. sdram holds on lock only.
    wire reset_wire = RESET | load_active | ~bios_ever_loaded | interact_reset
                    | splashscreen_sync2 | splash_reset_hold | splash_pending_sync2;
    wire reset_sdram_wire = RESET;

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
    // HOST BRIDGE
    //

    // Bridge reads: 0xF8=command window, 0x6=softcore dataslot read-back, else 0. The
    // softcore word is registered on bridge_rd (the APF samples before pulsing rd) and
    // gated to 0x6 so a command-window read cannot clobber it.
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

    // APF host<->core commands (status, dataslot, data table) on clk_74a; savestate,
    // RTC and on-screen-notify are unused and tied off.

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

    // Datatable scan: re-declare the Settings size (word 13, else a 0-size slot never
    // flushes) and read the HDD sizes (words 9/11, never seen as dataslot updates).
    // Reads land two cycles after the address.
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

    //
    // STORAGE SOFTCORE
    //

    // Disk management bus, mastered by the disk softcore (u_softcpu, below).
    wire [15:0] mgmt_din;              // CHIPSET readdata -> softcore
    wire [15:0] mgmt_dout;             // softcore -> CHIPSET write data
    wire [15:0] mgmt_addr;             // softcore -> CHIPSET address
    wire        mgmt_rd;               // softcore -> CHIPSET read strobe
    wire        mgmt_wr;               // softcore -> CHIPSET write strobe
    wire  [7:0] mgmt_req;              // [7:6] fdd request, [2:0] ide0 (from CHIPSET)
    assign mgmt_req[5:3] = 3'b000;

    // Floppy size arrives once as a dataslot update (bytes); HDD sizes come from the
    // datatable scan above. Slots (match firmware *_SLOT_ID + data.json): 1 BIOS,
    // 2 EC00 ROM, 3/4 floppy 0/1, 5/6 IDE 0/1.
    reg [31:0] fdd0_slot_bytes_74a = 32'd0;
    reg [31:0] fdd1_slot_bytes_74a = 32'd0;
    always @(posedge clk_74a) begin
        if (dataslot_update && dataslot_update_id == 16'd3)
            fdd0_slot_bytes_74a <= dataslot_update_size;
        if (dataslot_update && dataslot_update_id == 16'd4)
            fdd1_slot_bytes_74a <= dataslot_update_size;
    end

    // A floppy (re)bind arrives as a dataslot update (fires even on a same-size swap).
    // Toggle a per-drive bit on its rising edge so the firmware re-mounts and floppy.v
    // re-asserts media-change (edge, not level: the pulse spans several cycles).
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

    // OSD interconnect: the video-stage raster counters locate the framebuffer read;
    // the softcore returns a 4bpp palette index + in-area flag, composited there.
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

    //
    // SETTINGS
    //

    localparam tandy_video_mode = `ENABLE_TANDY_VIDEO;

    wire [1:0] buttons;
    wire [7:0] xtctl;

    // Interact "Reset PC" (0x50): stretch the one-shot write to a level, sync to the
    // chipset clock, and fold into the guest reset so the machine re-POSTs.
    reg [19:0] interact_reset_delay = 20'd0;
    // Interact "Extra Options" (0x54): same one-shot stretch to the softcore, which
    // opens the settings OSD (the guaranteed opener if Button Select was remapped).
    reg [19:0] osd_open_delay = 20'd0;
    // Interact list settings: each latched write-only from its bridge address, then
    // synced into the core clock below.
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
    // Pad button words come from an unvalidated ~1 ms poll and can bounce, so publish
    // a word only after it holds ~3.5 ms; analog axes are level-read and pass raw.
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
    wire [1:0] wp_cfg;
    wire [2:0] palette_cfg;

    // osd_* are in the clk_chipset domain (clk_pico is a gated clk_chipset).
    wire [1:0] cpu_speed_cfg  = osd_cpu_speed;
    wire [1:0] bios_wr_cfg    = osd_bios_wr;
    wire [1:0] opl2_cfg       = osd_opl2;
    wire [1:0] boost_cfg      = osd_boost;
    wire [1:0] spk_vol_cfg    = osd_spk_vol;
    wire [1:0] stereo_mix_cfg = osd_stereo;
    wire       cms_cfg        = osd_cms;
    wire       ems_en_cfg     = osd_ems;
    wire [1:0] ems_frame_cfg  = osd_ems_frame;
    wire       a000_en_cfg    = osd_a000;
    wire       video_1st_cfg  = osd_video_1st;
    synch_3              s_interact_reset (|interact_reset_delay, interact_reset, clk_chipset);
    synch_3              s_osd_open       (|osd_open_delay,    osd_open_req,  clk_chipset);
    synch_3 #(.WIDTH(2)) s_wp_cfg         (wp_cfg_74a,        wp_cfg,        clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_a          (key_a_74a,         key_a,         clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_b          (key_b_74a,         key_b,         clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_x          (key_x_74a,         key_x,         clk_chipset);
    synch_3 #(.WIDTH(8)) s_key_y          (key_y_74a,         key_y,         clk_chipset);
    synch_3 #(.WIDTH(2)) s_gamepad        (gamepad_74a,       gamepad_mode,  clk_chipset);
    synch_3 #(.WIDTH(8)) s_select_cfg     (select_cfg_74a,    select_cfg,    clk_chipset);
    synch_3 #(.WIDTH(8)) s_start_cfg      (start_cfg_74a,     start_cfg,     clk_chipset);
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

    // Controller-button config: key_* = per-face-button Set-2 scancode; gamepad_mode
    // picks what the pad drives (mapped keys, game port, or serial mouse).
    wire [7:0]  key_a, key_b, key_x, key_y;
    wire [1:0]  gamepad_mode;
    wire        gamepad  = (gamepad_mode == 2'd1);
    wire        mousepad = (gamepad_mode == 2'd2);
    // Button Select/Start: 0xF1=Settings, 0xF2=Pause/Credits, 0xF3=CGA/HGC toggle, else
    // a Set-2 key. Split into an OSD function id and a key scancode (0 for the functions).
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
    wire [1:0]  joy1_cfg = osd_joy1, joy2_cfg = osd_joy2;
    wire        swapjoy_cfg = osd_swapjoy, syncjoy_cfg = osd_syncjoy;
    wire [4:0]  joy_opts = {syncjoy_cfg, joy2_cfg, joy1_cfg};

    wire composite_cfg = osd_composite;   // CGA composite colour decode (settings bank, 0x7C)
    wire cga_gfx_cfg = osd_cga_gfx, hgc_gfx_cfg = osd_hgc_gfx;   // CGA/HGC graphics I/O enables (0 = Yes)
    wire composite = composite_cfg | xtctl[0];
    wire a000h = `ENABLE_A000_UMB ? (a000_en_cfg & ~xtctl[6]) : 1'b0;
    wire [2:0] vsync_width_osd = 3'd0;  // 0=Auto (use register), 1-7=override
    wire [2:0] hsync_width_osd = 3'd0;  // 0=Auto, 1-7=fixed width (Nx16 pixel clocks)

    reg         hgc_mode_video_ff;
    reg         cga_hw;
    reg         hercules_hw;

    always @(posedge clk_chipset)
    begin
        cga_hw                  <= `ENABLE_CGA ? (`ENABLE_HGC ? (~cga_gfx_cfg | tandy_video_mode) : 1'b1) : 1'b0;
        hercules_hw             <= `ENABLE_HGC ? (`ENABLE_CGA ? ~hgc_gfx_cfg : 1'b1) : 1'b0;
    end

    always @(posedge clk_chipset)
        hgc_mode_video_ff       <= `ENABLE_HGC ? hgc_mode : 1'b0;

    // MiSTer front-panel buttons; the Pocket has none.
    assign buttons = 2'b00;

    //
    // INPUT
    //

    wire  [7:0] kb_byte;
    wire        kb_valid;
    wire        kb_ready;

    wire        mouse_rd;
    wire        mouse_rts_n;

    wire [13:0] joy0, joy1;
    wire [15:0] joya0, joya1;

    // Pocket controllers -> game-port digital bits: [5]=fire2 [4]=fire1 [3]=up [2]=down
    // [1]=left [0]=right, from cont key bits [0]=up [1]=down [2]=left [3]=right [4]=A [5]=B.
    wire [13:0] cont1_dig = {8'd0, cont1_key_chip[5], cont1_key_chip[4],
                                   cont1_key_chip[0], cont1_key_chip[1],
                                   cont1_key_chip[2], cont1_key_chip[3]};
    wire [13:0] cont2_dig = {8'd0, cont2_key_chip[5], cont2_key_chip[4],
                                   cont2_key_chip[0], cont2_key_chip[1],
                                   cont2_key_chip[2], cont2_key_chip[3]};
    // Left stick -> analog: Pocket axes are unsigned centred on 0x80, the port wants
    // signed centred on 0, so flip the top bit. An all-zero pad (no analog) is held at
    // centre (a raw 0 would otherwise read as full deflection).
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

    //
    // Keyboard: pad buttons + docked USB keyboard + VKB merged into one Set-2 byte
    // stream (kb_byte/kb_valid, paced by kb_ready). In mouse mode the D-pad and A/B
    // drop out (they drive the mouse); X/Y and Select/Start stay mapped keys.
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
    // Mouse: docked USB mouse (cont4_*) -> Microsoft serial byte stream on COM1, paced
    // by RTS. In mouse mode the pad's D-pad and A/B drive it too; quiet under an overlay.
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

    //
    // ROM AND BIOS LOAD
    //

    wire        ioctl_download;
    wire  [7:0] ioctl_index;
    wire        ioctl_wr;
    wire [24:0] ioctl_addr;
    wire [15:0] ioctl_data;
    reg         ioctl_wait;

    // ROM-load reset hold: keep the machine in reset while APF streams a slot, and from
    // power-on until the first load lands, so the CPU never runs without a BIOS. The
    // BIOS write path sits on the separate reset_sdram.
    wire        is_downloading;      // APF slot load active (clk_chipset)
    wire        load_active;         // is_downloading OR the FIFO still draining
    reg         bios_ever_loaded = 1'b0;

    // Track an APF->core slot stream (requestwrite..allcomplete) on the bridge clock,
    // then sync into the chipset domain for the loader and reset hold.
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

    // APF streams the BIOS slot into the 0x1xxxxxxx window; data_loader makes 16-bit
    // (addr,data) writes. APF can't be backpressured, so a FIFO catches every write and
    // the copier feeds the BIOS FSM as an ioctl stream that honours ioctl_wait.
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

    // Decoupling FIFO, entry = {xtide, addr[24:0], data[15:0]}: the slot tag rides each
    // entry so a later stream can't retag a draining tail. 256 deep; the handshake loader
    // keeps it shallow and load_active holds reset until it drains, so it never overflows.
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

                    // Hold the external write until ram_rw_complete, or a safety
                    // timeout (a hang backstop; a normal write never reaches it).
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

    //
    // SPLASH
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
    reg splash_reset_hold = 0;
    reg [16:0] splash_reset_cnt = 17'd0;
    localparam [16:0] SPLASH_RESET_HOLD = 17'd131072;
    reg phys_reset_hold = 0;
    reg [23:0] phys_reset_cnt = 24'd0;
    localparam [23:0] PHYS_RESET_HOLD = 24'd2863600;
    wire splash_on_28_cfg;
    wire video_1st_28;
    wire bios_ever_loaded_28;
    synch_3 s_splash_on   (splash_cfg_74a,   splash_on_28_cfg,    clk_28_636);
    synch_3 s_video_1st   (osd_video_1st,    video_1st_28,        clk_28_636);
    synch_3 s_bios_loaded (bios_ever_loaded, bios_ever_loaded_28, clk_28_636);
    // The splash draws into CGA VRAM, so a Hercules boot skips it rather than
    // holding the machine on a blank mono screen.
    wire splash_on_28 = splash_on_28_cfg & ~video_1st_28;

    always @(posedge clk_28_636)
    if (ce_14_318)
    begin
        splash_off <= ~splash_on_28;
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
            if (bios_ever_loaded_28)
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

    //
    // THE MACHINE
    //

    wire VGA_VBlank_border;
    wire std_hsyncwidth;
    wire pause_core_chipset;
    wire swap_video;

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
    //  .processor_transmit_or_receive_n    (processor_transmit_or_receive_n),
        .processor_ready                    (processor_ready),
        .interrupt_to_cpu                   (interrupt_to_cpu),
        .splashscreen                       (splashscreen),
        .status0_clear                      (1'b0),
        .std_hsyncwidth                     (std_hsyncwidth),
        .composite                          (composite),
        .video_output                       (video_output_sel),
        .clk_vga_cga                        (clk_28_636),
        .enable_cga                         (`ENABLE_CGA),
        .clk_vga_hgc                        (clk_32_514),
        .enable_hgc                         (enable_hgc_sel),
        .hgc_rgb                            (hgc_rgb_sel),
    //  .de_o                               (VGA_DE),
        .VGA_R                              (r),
        .VGA_G                              (g),
        .VGA_B                              (b),
        .VGA_HSYNC                          (HSync),
        .VGA_VSYNC                          (VSync),
        .VGA_HBlank                         (HBlank),
        .VGA_VBlank                         (VBlank),
        .VGA_VBlank_border                  (VGA_VBlank_border),
    //  .address                            (address),
        .address_ext                        (bios_access_address),
        .ext_access_request                 (bios_access_request),
        .address_direction                  (address_direction),
        .data_bus                           (data_bus),
        .data_bus_ext                       (bios_write_data[7:0]),
    //  .data_bus_direction                 (data_bus_direction),
        .address_latch_enable               (address_latch_enable),
    //  .io_channel_check                   (),
        .io_channel_ready                   (1'b1),
        .interrupt_request                  (0),    // use? -> It does not seem to be necessary.
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
        .dma_request                        (0),    // use? -> I don't know if it will ever be necessary, at least not during testing.
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
        .cga_scandouble_en                  (1'b0),
        .hercules_hw                        (hercules_hw_sel),
        .swap_video                         (swap_video),
        .crt_h_offset                       (4'd0),
        .crt_v_offset                       (3'd0),
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
    // MACHINE PORT STUBS
    //

    wire uart_tx, uart_rts, uart_dtr;   // CHIPSET COM2 outputs, no external pins
    wire uart_rx  = 1'b1;
    wire uart_cts = 1'b1;
    wire uart_dsr = 1'b1;
    wire uart_dcd = 1'b1;

    // SPI/MMC storage path unused; the managed-SD ide.v backend is used instead.
    wire [1:0] use_mmc = 2'b00;
    wire spi_clk, spi_cs, spi_mosi;     // CHIPSET outputs, no external pins
    wire spi_miso = 1'b0;

    //
    // AUDIO
    //

    wire [15:0] cms_l_snd_e;
    wire [16:0] cms_l_snd = {cms_l_snd_e[15],cms_l_snd_e};
    wire [15:0] cms_r_snd_e;
    wire [16:0] cms_r_snd = {cms_r_snd_e[15],cms_r_snd_e};
     
    wire [15:0] jtopl2_snd_e;
    wire [16:0] jtopl2_snd = {jtopl2_snd_e[15], jtopl2_snd_e};
    wire [10:0] tandy_snd_e;
    wire [16:0] tandy_snd = `ENABLE_TANDY_AUDIO ? {{{2{tandy_snd_e[10]}}, {4{tandy_snd_e[10]}}, tandy_snd_e}, 2'b00} : 17'd0;
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

    // Filter chain + I2S: audio_mixer supplies the anti-aliasing low-pass + DC blocker
    // (the raw mix has square-wave harmonics past Nyquist), the crossfeed, and codec clocks.
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
    // VIDEO AND OSD
    //

    // CGA/HGC picture -> Pocket scaler (which does the scaling/filtering). CGA blanking
    // passes through; the Hercules raster is reshaped into the fixed canvas below.
    // r/g/b + syncs leave CHIPSET on the dot clock; clk_pix is its half-rate sibling,
    // so it samples one pixel per edge.

    wire        HBlank;
    wire        HSync;
    wire        VBlank;
    wire        VSync;
    wire [5:0]  r, g, b;
    wire        tandy_16_gfx, tandy_color_16;   // CHIPSET Tandy-video outputs (unused)

    // Monochrome-monitor palette (Display setting): palette_cfg 0 = full colour, 1-7
    // tint by weighted luma. Combinational (no extra clock/latency); r/g/b widened to 8.
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

    // Hercules canvas: the guest programs arbitrary 6845 rasters, so present one fixed
    // 720x350 window (720 dots from the guest active start each line, 350 lines opening
    // CANVAS_VSKIP lines after the vsync fall) and pad the rest black. CANVAS_VSKIP must
    // equal the scaler's frame anchor, or the window's top lines wrap to the bottom.
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
    // Canvas padding (inside the window, outside the guest raster). The window's first
    // line is sacrificial/black: the scaler captures the first DE line unreliably.
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

    // OSD raster counters: osd_hcnt = pixel in the active line; the line index is the
    // canvas countdown on Hercules, else an hblank-fall counter parked at -1 so the
    // first fall (after VBlank) is line 0.
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

    // Scaler slot (video.json): 0 = CGA 640x200, 1 = Hercules canvas; follows only the
    // displayed card.
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

    // Stage HSync/VSync one clk_pix (hs_d/vs_d) to match the credits overlay's 1-cycle
    // HB/VB/RGB latency. While DE is low the bus carries the scaler-slot word ([23:13]),
    // held through all of blanking: a zero bus is itself slot 0 and the last word wins.
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
