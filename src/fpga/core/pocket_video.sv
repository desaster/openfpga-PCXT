//
// Pocket video output: composite the machine's CGA/HGC raster and the softcore's OSD
// framebuffer into the Analogue APF scaler stream. The CGA raster is the pass-through
// default; the stages below special-case only what differs from it: the monochrome
// palette tint, the fixed Hercules canvas, the credits and sync-guard overlays, and the
// final pack of RGB + single-cycle HS/VS + DE with the scaler-slot word held through
// blanking. Runs on clk_pix, the CGA dot clock's half-rate sibling (one pixel per edge).
//

module pocket_video (
    input             clk_pix,
    input             clk_pix_90,
    input             RESET,
    // Machine raster (from CHIPSET, clk_pix-sampled)
    input      [5:0]  r,
    input      [5:0]  g,
    input      [5:0]  b,
    input             HSync,
    input             VSync,
    input             HBlank,
    input             VBlank,
    // Config / clock-mux state
    input      [2:0]  palette_cfg,
    input             credits_mode_pix,
    input             pix_sel,
    input             vid_blank,
    // OSD framebuffer handshake (softcore)
    input             osd_active,
    input      [3:0]  osd_palette_idx,
    input             osd_in_area,
    output reg [9:0]  osd_hcnt,
    output     [9:0]  osd_vcnt,
    output     [9:0]  osd_raster_w,
    output     [9:0]  osd_raster_h,
    // Analogue APF scaler
    output     [23:0] video_rgb,
    output            video_de,
    output            video_hs,
    output            video_vs,
    output            video_skip,
    output            video_rgb_clock,
    output            video_rgb_clock_90
);

    //
    // Palette tint
    //
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

    //
    // Hercules canvas
    //
    // The guest programs arbitrary 6845 rasters, so present one fixed 720x350 window
    // (720 dots from the guest active start each line, 350 lines opening CANVAS_VSKIP
    // lines after the vsync fall) and pad the rest black. CANVAS_VSKIP must equal the
    // scaler's frame anchor, or the window's top lines wrap to the bottom.
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

    //
    // Card blanking
    //
    // The Hercules canvas when that card is shown, the CGA HBlank/VBlank otherwise
    // (cga.v already normalizes every CGA mode to 640x200).
    wire vid_hb  = hgc_shown_pix ? canvas_hb : HBlank;
    wire vid_vb  = hgc_shown_pix ? canvas_vb : VBlank;
    // Canvas padding (inside the window, outside the guest raster). The window's first
    // line is sacrificial/black: the scaler captures the first DE line unreliably.
    wire vid_pad = hgc_shown_pix & (HBlank | VBlank | (v_run == CANVAS_H));

    //
    // Credits overlay
    //
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
        .HB_out     (             ),
        .VB_out     (             ),
        .rgb_out    ( credits_rgb )
    );

    //
    // Overlay sync guard
    //
    // When the guest video timing leaves spec (a guest can program the CRTC to stall HSYNC
    // or suppress VSYNC), supply a stable frame for an open OSD/VKB to ride on so it stays
    // framed. `guard_run` engages only on the CGA path with an overlay open.
    wire osd_enable;
    synch_3 s_osd_enable_pix (osd_active, osd_enable, clk_pix);

    wire guard_run, gen_hs, gen_vs, gen_hb, gen_vb;
    video_sync_guard u_sync_guard (
        .clk_pix      (clk_pix),
        .overlay_open (osd_enable & ~hgc_shown_pix & ~credits_mode_pix),
        .hsync_in     (HSync),
        .vsync_in     (VSync),
        .hblank_in    (HBlank),
        .vblank_in    (VBlank),
        .run          (guard_run),
        .gen_hs       (gen_hs),
        .gen_vs       (gen_vs),
        .gen_hb       (gen_hb),
        .gen_vb       (gen_vb)
    );

    //
    // Presented raster
    //
    // The guest's raster, or the sync guard's generated frame once it has taken over.
    // Everything downstream (OSD counters, output sync, DE) rides on these four.
    wire sel_hs = guard_run ? gen_hs : HSync;
    wire sel_vs = guard_run ? gen_vs : VSync;
    wire sel_hb = guard_run ? gen_hb : vid_hb;
    wire sel_vb = guard_run ? gen_vb : vid_vb;

    // The credits overlay delays its picture one clk_pix; stage the presented sync/blanking
    // to match, so both align with the composited RGB at the final register. sel_hb_d1 also
    // gives the OSD line counter its hblank-fall edge.
    reg sel_hs_d1 = 1'b0, sel_vs_d1 = 1'b0;
    reg sel_hb_d1 = 1'b0, sel_vb_d1 = 1'b0;
    always @(posedge clk_pix) begin
        sel_hs_d1 <= sel_hs;
        sel_vs_d1 <= sel_vs;
        sel_hb_d1 <= sel_hb;
        sel_vb_d1 <= sel_vb;
    end

    //
    // OSD framebuffer readout
    //
    // OSD raster counters: osd_hcnt = pixel in the active line; the line index is the
    // canvas countdown on Hercules, else an hblank-fall counter parked at -1 so the
    // first fall (after VBlank) is line 0.
    reg [9:0] osd_vcnt_raw = 10'd0;
    always @(posedge clk_pix) begin
        if (sel_hb)                   osd_hcnt <= 10'd0;
        else                          osd_hcnt <= osd_hcnt + 10'd1;
        if (sel_vb)                   osd_vcnt_raw <= 10'd1023;
        else if (sel_hb_d1 & ~sel_hb) osd_vcnt_raw <= osd_vcnt_raw + 10'd1;
    end
    assign osd_vcnt = hgc_shown_pix ? (CANVAS_H - 10'd1 - v_run) : osd_vcnt_raw;

    // Presented raster size, read by the softcore to place the overlay window;
    // the canvas reports its 349 usable lines, excluding the sacrificial one.
    assign osd_raster_w = pix_sel ? CANVAS_W : 10'd640;
    assign osd_raster_h = pix_sel ? (CANVAS_H - 10'd1) : 10'd200;

    // Framebuffer palette index -> opaque colour; index 0 is transparent and
    // falls through to the picture.
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

    //
    // Scaler output
    //
    // Scaler slot (video.json): 0 = CGA 640x200, 1 = Hercules canvas; follows only the
    // displayed card.
    wire [2:0] vid_slot = hgc_shown_pix ? 3'd1 : 3'd0;

    // Final pack: DE from the staged presented blanking, the overlay layered over the
    // picture (black behind it under the sync guard), sync staged to match. While DE is low
    // the bus carries the scaler-slot word ([23:13]), held through all of blanking: a zero
    // bus is itself slot 0 and the last word wins.
    reg  [23:0] vid_rgb = 24'd0;
    reg         vid_de  = 1'b0;
    reg         vid_hs  = 1'b0;
    reg         vid_vs  = 1'b0;
    wire        vid_de_now = ~(sel_hb_d1 | sel_vb_d1) & ~vid_blank_pix;
    wire [23:0] overlay    = osd_show  ? osd_color
                           : guard_run ? 24'd0
                           :             credits_rgb;
    always @(posedge clk_pix) begin
        vid_de  <= vid_de_now;
        vid_rgb <= vid_de_now ? overlay : {8'd0, vid_slot, 13'd0};
        vid_hs  <= sel_hs_d1;
        vid_vs  <= sel_vs_d1;
    end

    assign video_rgb          = vid_rgb;
    assign video_de           = vid_de;
    assign video_hs           = vid_hs;
    assign video_vs           = vid_vs;
    assign video_skip         = 1'b0;
    assign video_rgb_clock    = clk_pix;
    assign video_rgb_clock_90 = clk_pix_90;

endmodule
