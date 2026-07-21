//
// Overlay video sync guard: hands an open OSD/VKB a stable frame to ride on when the guest
// video timing leaves spec. A guest can program the CRTC to stall HSYNC or suppress VSYNC,
// on which an overlay read out would become unreadable; the generator tracks the guest
// raster while it is in spec and free-runs the last-good geometry once it is not. `run`
// asserts only for the out-of-spec case, so a healthy raster passes through untouched.
//

module video_sync_guard (
    input        clk_pix,
    input        overlay_open,   // an OSD/VKB is up on the CGA path
    input        hsync_in,       // raw CGA sync/blanking, clk_pix domain
    input        vsync_in,
    input        hblank_in,
    input        vblank_in,
    output       run,            // present the generated frame in place of the guest
    output       gen_hs,         // generated sync/blanking (replayed last-good geometry)
    output       gen_vs,
    output       gen_hb,
    output       gen_vb
);

    // clk_pix ticks / lines. A stalled HSYNC or a suppressed VSYNC exceeds the timeouts.
    localparam [11:0] MIN_LINE  = 12'd600;
    localparam [11:0] MAX_LINE  = 12'd1400;
    localparam [11:0] H_TIMEOUT = 12'd1400;
    localparam [9:0]  V_TIMEOUT = 10'd400;
    localparam [9:0]  MIN_FRAME = 10'd200;
    localparam [9:0]  MAX_FRAME = 10'd350;
    localparam [1:0]  GOOD_REQ  = 2'd2;    // clean frames before handing back to the guest

    reg  hs_d, vs_d, hb_d, vb_d;
    wire hs_rise = hsync_in  & ~hs_d;
    wire vs_rise = vsync_in  & ~vs_d;
    wire hs_fall = ~hsync_in & hs_d;
    wire vs_fall = ~vsync_in & vs_d;
    wire hb_fall = ~hblank_in & hb_d;
    wire hb_rise = hblank_in  & ~hb_d;
    wire vb_fall = ~vblank_in & vb_d;
    wire vb_rise = vblank_in  & ~vb_d;

    // Position from the HSYNC/VSYNC rising edges, saturating so a stall trips the timeout.
    reg  [11:0] hpos;
    reg  [9:0]  vpos;
    // This frame's geometry, as offsets from those edges.
    reg  [11:0] m_htotal, m_hs_end, m_hb_end, m_hb_start;
    reg  [9:0]  m_vs_end, m_vb_end, m_vb_start;
    // Geometry the generator replays; a nominal 640x200 frame until the first capture.
    reg  [11:0] g_htotal = 12'd912, g_hs_end = 12'd100,
                g_hb_end = 12'd180, g_hb_start = 12'd820;
    reg  [9:0]  g_vtotal = 10'd262, g_vs_end = 10'd3,
                g_vb_end = 10'd30,  g_vb_start = 10'd230;

    reg  insync    = 1'b0;
    reg  frame_bad = 1'b0;
    reg  [1:0] good = 2'd0;

    wire line_bad = hs_rise & ((hpos < MIN_LINE) | (hpos > MAX_LINE));
    wire timeout  = (hpos > H_TIMEOUT) | (vpos > V_TIMEOUT);
    // Replayable only if the active windows are ordered.
    wire meas_ok  = (m_hb_end < m_hb_start) & (m_vb_end < m_vb_start)
                  & (m_htotal >= MIN_LINE) & (m_htotal <= MAX_LINE);

    always @(posedge clk_pix) begin
        hs_d <= hsync_in; vs_d <= vsync_in; hb_d <= hblank_in; vb_d <= vblank_in;

        if (hs_rise)               hpos <= 12'd0;
        else if (~&hpos)           hpos <= hpos + 12'd1;
        if (vs_rise)               vpos <= 10'd0;
        else if (hs_rise & ~&vpos) vpos <= vpos + 10'd1;

        if (hs_rise) m_htotal   <= hpos;
        if (hs_fall) m_hs_end   <= hpos;
        if (hb_fall) m_hb_end   <= hpos;
        if (hb_rise) m_hb_start <= hpos;
        if (vs_fall) m_vs_end   <= vpos;
        if (vb_fall) m_vb_end   <= vpos;
        if (vb_rise) m_vb_start <= vpos;

        // Drop sync at once on a timeout; require GOOD_REQ clean frames to re-engage.
        if (line_bad | timeout) frame_bad <= 1'b1;
        if (timeout) begin insync <= 1'b0; good <= 2'd0; end

        if (vs_rise) begin
            frame_bad <= 1'b0;
            if (frame_bad | ~meas_ok | (vpos < MIN_FRAME) | (vpos > MAX_FRAME)) begin
                insync <= 1'b0;
                good   <= 2'd0;
            end else begin
                g_htotal <= m_htotal; g_hs_end   <= m_hs_end;
                g_hb_end <= m_hb_end; g_hb_start <= m_hb_start;
                g_vtotal <= vpos;     g_vs_end   <= m_vs_end;
                g_vb_end <= m_vb_end; g_vb_start <= m_vb_start;
                if (good >= GOOD_REQ) insync <= 1'b1;
                else                  good   <= good + 2'd1;
            end
        end
    end

    // Reset to the guest edges while in spec, so the handover carries no phase jump.
    reg  [11:0] gen_h;
    reg  [9:0]  gen_v;
    wire gen_h_wrap = (gen_h >= g_htotal - 12'd1);
    always @(posedge clk_pix) begin
        if (insync) begin
            gen_h <= hs_rise ? 12'd0 : (gen_h_wrap ? 12'd0 : gen_h + 12'd1);
            if (vs_rise)      gen_v <= 10'd0;
            else if (hs_rise) gen_v <= (gen_v >= g_vtotal - 10'd1) ? 10'd0 : gen_v + 10'd1;
        end else begin
            gen_h <= gen_h_wrap ? 12'd0 : gen_h + 12'd1;
            if (gen_h_wrap)   gen_v <= (gen_v >= g_vtotal - 10'd1) ? 10'd0 : gen_v + 10'd1;
        end
    end

    assign gen_hs = (gen_h < g_hs_end);
    assign gen_vs = (gen_v < g_vs_end);
    assign gen_hb = ~((gen_h >= g_hb_end) & (gen_h < g_hb_start));
    assign gen_vb = ~((gen_v >= g_vb_end) & (gen_v < g_vb_start));
    assign run    = overlay_open & ~insync;

endmodule
