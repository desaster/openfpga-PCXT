//
// Pocket mouse: present the docked USB mouse (cont4_*) to the machine as a
// two-button Microsoft serial mouse on COM1: an 'M' identification byte when
// the driver asserts RTS, then three-byte movement packets at 1200 baud.
//

module pocket_mouse (
    input         clk,          // clk_chipset (50 MHz)
    input  [31:0] cont4_joy,    // docked USB: buttons [23:16], X delta [15:0]
    input  [15:0] cont4_key,    // docked USB: report counter
    input  [15:0] cont4_trig,   // docked USB: Y delta
    input  [5:0]  pad,          // gamepad mouse mode: {B, A, right, left, down, up}, 0 when off
    input         rts_n,        // COM1 RTS; the assert edge requests identification
    output reg    rd = 1'b1     // serial data into COM1 RX
);

    //
    // Report capture. The dock rewrites the three cont4 words one at a time,
    // so a raw crossing could pair a new report counter with a stale delta.
    // Latch a snapshot only after all three words have held steady for
    // ~160 us (longer than the gap between the dock's word writes, well
    // inside its poll period): each snapshot is then one complete report,
    // consumed once when its counter changes.
    //
    reg [31:0] joy_s0, joy_s1, joy_s;
    reg [15:0] key_s0, key_s1, key_s;
    reg [15:0] trig_s0, trig_s1, trig_s;
    reg [12:0] rpt_stable;
    wire       rpt_steady = (joy_s0 == joy_s1) && (key_s0 == key_s1) && (trig_s0 == trig_s1);

    always @(posedge clk) begin
        joy_s0  <= cont4_joy;  joy_s1  <= joy_s0;
        key_s0  <= cont4_key;  key_s1  <= key_s0;
        trig_s0 <= cont4_trig; trig_s1 <= trig_s0;
        if (!rpt_steady)
            rpt_stable <= 13'd0;
        else if (!(&rpt_stable))
            rpt_stable <= rpt_stable + 13'd1;
        else begin
            joy_s  <= joy_s1;
            key_s  <= key_s1;
            trig_s <= trig_s1;
        end
    end

    // Report fields, little endian; deltas signed, Y positive downward as the
    // serial protocol expects.
    wire signed [15:0] rpt_dx  = {joy_s[7:0], joy_s[15:8]};
    wire signed [15:0] rpt_dy  = {trig_s[7:0], trig_s[15:8]};
    wire         [1:0] rpt_btn = joy_s[17:16];   // [0] = left, [1] = right

    //
    // Sensitivity: scale each arriving report's deltas by 1/8 (tuned on
    // hardware), rounding toward zero so both directions quantise alike, and
    // carry the remainder per axis so slow motion is scaled rather than lost.
    //
    reg signed [3:0] res_x = 4'sd0, res_y = 4'sd0;

    function signed [16:0] tzshr3(input signed [16:0] v);
        tzshr3 = v[16] ? -((-v) >>> 3) : (v >>> 3);
    endfunction

    wire signed [16:0] scl_x  = res_x + rpt_dx;
    wire signed [16:0] scl_y  = res_y + rpt_dy;
    wire signed [16:0] out_x  = tzshr3(scl_x);
    wire signed [16:0] out_y  = tzshr3(scl_y);
    wire signed [16:0] nres_x = scl_x - (out_x <<< 3);
    wire signed [16:0] nres_y = scl_y - (out_y <<< 3);

    //
    // Accumulate scaled deltas between packets, saturating at the packet's
    // signed 8-bit range; reports arriving while a packet is in flight sum
    // into the next one.
    //
    reg  [15:0]       rpt_count = 16'd0;   // counter of the last consumed report
    reg  signed [7:0] acc_x = 8'sd0, acc_y = 8'sd0;
    reg  [1:0]        btn = 2'd0, btn_sent = 2'd0;

    wire rpt_new = (key_s != rpt_count);

    function signed [7:0] sat8(input signed [16:0] v);
        sat8 = (v > 17'sd127) ? 8'sd127 : (v < -17'sd127) ? -8'sd127 : v[7:0];
    endfunction

    //
    // Gamepad mouse: while a D-pad direction is held, step the accumulators
    // at a fixed rate (tuned on hardware); A and B act as the left and right
    // buttons alongside the docked mouse's.
    //
    localparam [17:0] PAD_DIV = 18'd249_999;   // 50 MHz / 200 counts per second, minus one

    reg [17:0] pad_div = 18'd0;
    wire       pad_tick = (pad_div == 18'd0) && (pad[3:0] != 4'd0);

    wire signed [1:0] pad_dx = pad[3] ? 2'sd1 : pad[2] ? -2'sd1 : 2'sd0;
    wire signed [1:0] pad_dy = pad[1] ? 2'sd1 : pad[0] ? -2'sd1 : 2'sd0;
    wire        [1:0] btn_now = btn | {pad[5], pad[4]};

    //
    // Serial transmit: a 30-bit frame (three 10-bit 7N1 bytes, LSB first)
    // shifted out at 1200 baud, line idle high. Packet byte 1 carries the sync
    // flag (bit 6), buttons and delta bits 7:6; bytes 2 and 3 the low six
    // delta bits. Bit 7 is 1 on every byte, so an 8-bit read sees a stop bit
    // in its place.
    //
    localparam [15:0] BAUDDIV = 16'd41665;   // 50 MHz / 1200 baud, minus one

    // 'M' identification, led by 20 bit times of idle line: the power-up
    // settle a driver waits out after asserting RTS.
    localparam [29:0] FRAME_M = 30'h39AFFFFF;

    wire [7:0]  pkt_b1 = {2'b11, btn_now[0], btn_now[1], acc_y[7:6], acc_x[7:6]};
    wire [7:0]  pkt_b2 = {2'b10, acc_x[5:0]};
    wire [7:0]  pkt_b3 = {2'b10, acc_y[5:0]};
    wire [29:0] frame_pkt = {1'b1, pkt_b3, 2'b01, pkt_b2, 2'b01, pkt_b1, 1'b0};

    reg [29:0] shift   = {30{1'b1}};
    reg  [4:0] bits    = 5'd0;
    reg [15:0] baud    = 16'd0;
    reg        rts_n_q = 1'b1;

    wire rts_assert = rts_n_q & ~rts_n;
    wire tx_idle    = (bits == 5'd0) && (baud == 16'd0);
    wire pkt_load   = tx_idle && !rts_n &&
                      ((acc_x != 8'sd0) || (acc_y != 8'sd0) || (btn_now != btn_sent));

    // A packet load empties the accumulators; a report or pad step landing
    // that same cycle still folds in.
    wire signed [16:0] sum_x = (pkt_load ? 17'sd0 : acc_x) + (rpt_new ? out_x : 17'sd0)
                             + (pad_tick ? pad_dx : 2'sd0);
    wire signed [16:0] sum_y = (pkt_load ? 17'sd0 : acc_y) + (rpt_new ? out_y : 17'sd0)
                             + (pad_tick ? pad_dy : 2'sd0);

    always @(posedge clk) begin
        rts_n_q <= rts_n;

        pad_div <= (pad_div == 18'd0) ? PAD_DIV : pad_div - 18'd1;

        if (rpt_new) begin
            rpt_count <= key_s;
            btn       <= rpt_btn;
        end
        if (rts_assert) begin
            res_x <= 4'sd0;
            res_y <= 4'sd0;
        end else if (rpt_new) begin
            res_x <= nres_x[3:0];
            res_y <= nres_y[3:0];
        end
        acc_x <= rts_assert ? 8'sd0 : sat8(sum_x);
        acc_y <= rts_assert ? 8'sd0 : sat8(sum_y);

        if (baud != 16'd0)
            baud <= baud - 16'd1;
        else if (bits != 5'd0) begin
            {shift, rd} <= {1'b1, shift};
            bits <= bits - 5'd1;
            baud <= BAUDDIV;
        end

        // The RTS assert edge answers 'M', aborting any frame in flight;
        // otherwise pending movement or a button change loads a packet.
        if (rts_assert || pkt_load) begin
            {shift, rd} <= {1'b1, rts_assert ? FRAME_M : frame_pkt};
            bits     <= 5'd29;
            baud     <= BAUDDIV;
            btn_sent <= btn_now;
        end
    end

endmodule
