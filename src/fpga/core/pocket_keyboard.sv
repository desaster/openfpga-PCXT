//
// Pocket keyboard: merge controller buttons and a docked USB keyboard onto the
// single PS/2 device that CHIPSET's KFPS2KB receives.
//
// KFPS2KB is a real PS/2 serial device, so both input sources must share one
// serialised output. Two event producers - the cont1_key button map and
// hid_to_ps2 over the docked USB keyboard (cont3_*) - push key events into a
// small queue; a framer drains it, emitting each as a Set-2 make ([code]) or
// break ([0xF0, code]) into the ps2_device serialiser.
//
// Scancodes are Set-2 (KFPS2KB converts Set-2 -> XT). Avoid F11 (0x78) / F12
// (0x07) in the button map: KFPS2KB consumes them for video-swap / pause.
//

module pocket_keyboard (
    input        clk,          // clk_chipset (50 MHz) = ps2_device clk_sys
    input        reset,
    input [15:0] buttons,      // cont1_key
    input [31:0] cont3_joy,    // docked USB: HID usage codes 1-4
    input [15:0] cont3_trig,   // docked USB: HID usage codes 5-6
    input [15:0] cont3_key,    // docked USB: modifier bits (byte [15:8])

    // host -> device from CHIPSET (idle high); device -> host into CHIPSET
    input        ps2_clk_host,
    input        ps2_dat_host,
    output       ps2_clk_dev,
    output       ps2_dat_dev
);

    //
    // PS/2 bit-clock timebase. Matches MiSTer PCXT (PS2DIV=2000 @ 50 MHz
    // -> ~12.5 kHz), the rate KFPS2KB_Shift_Register is proven against.
    //
    localparam [11:0] PS2DIV = 12'd2000;
    reg         clk_ps2 = 1'b0;
    reg  [11:0] ps2_cnt  = 12'd0;

    always @(posedge clk) begin
        if (reset) begin
            clk_ps2 <= 1'b0;
            ps2_cnt <= 12'd0;
        end else if (ps2_cnt == PS2DIV) begin
            clk_ps2 <= ~clk_ps2;
            ps2_cnt <= 12'd0;
        end else begin
            ps2_cnt <= ps2_cnt + 12'd1;
        end
    end

    //
    // Serialiser. FIFO depth 16 (bits=4) absorbs the multi-byte burst a chord on
    // the USB keyboard can produce. rx_full blocks TX writes while a host byte is
    // pending; rd auto-drains it so the BIOS reset command (0xFF) can't wedge it.
    //
    reg  [7:0] wdata;
    reg        we;
    wire [8:0] rdata;
    wire       rx_full = rdata[8];

    ps2_device #(.PS2_FIFO_BITS(4)) u_ps2_device (
        .clk_sys     (clk),
        .wdata       (wdata),
        .we          (we),
        .ps2_clk     (clk_ps2),
        .ps2_clk_out (ps2_clk_dev),
        .ps2_dat_out (ps2_dat_dev),
        .tx_empty    (),
        .ps2_clk_in  (ps2_clk_host),
        .ps2_dat_in  (ps2_dat_host),
        .rdata       (rdata),
        .rd          (rdata[8])
    );

    //
    // Source A: controller buttons. Synchronise cont1_key, then scan the 8 mapped
    // bits one per clock: [0]=up [1]=down [2]=left [3]=right [4]=A [5]=B [6]=X [7]=Y.
    //
    reg [7:0] btn_s0, btn_s, btn_prev;
    reg [2:0] btn_idx;

    function automatic [7:0] scancode;
        input [2:0] idx;
        case (idx)
            3'd0: scancode = 8'h75;  // up    -> keypad 8 / Up
            3'd1: scancode = 8'h72;  // down  -> keypad 2 / Down
            3'd2: scancode = 8'h6B;  // left  -> keypad 4 / Left
            3'd3: scancode = 8'h74;  // right -> keypad 6 / Right
            3'd4: scancode = 8'h0A;  // A     -> F8
            3'd5: scancode = 8'h06;  // B     -> F2
            3'd6: scancode = 8'h5A;  // X     -> Enter
            3'd7: scancode = 8'h76;  // Y     -> Esc
            default: scancode = 8'h00;
        endcase
    endfunction

    //
    // Source B: docked USB keyboard. Synchronise cont3_* into the clk domain and
    // convert to ps2_key events {strobe, pressed, 1'b0, code[7:0]}.
    //
    reg [31:0] joy_s0, joy_s;
    reg [15:0] trig_s0, trig_s;
    reg [15:0] key_s0, key_s;

    always @(posedge clk) begin
        joy_s0  <= cont3_joy;  joy_s  <= joy_s0;
        trig_s0 <= cont3_trig; trig_s <= trig_s0;
        key_s0  <= cont3_key;  key_s  <= key_s0;
    end

    wire [10:0] usb_key;
    hid_to_ps2 u_hid_to_ps2 (
        .clk     (clk),
        .reset   (reset),
        .joy     (joy_s),
        .trig    (trig_s),
        .mods    (key_s[15:8]),
        .ps2_key (usb_key)
    );

    //
    // Merge: one key event {make, code[7:0]} pushed per clock into a 16-deep
    // queue. Buttons take priority (momentary, few events); the button scanner
    // stalls rather than drop when the queue is full. The USB source cannot stall,
    // but a chord is a handful of events against 16 slots plus the 16-byte TX FIFO.
    //
    localparam QW = 4;
    reg  [8:0]    queue [0:(1<<QW)-1];
    reg  [QW-1:0] q_wr, q_rd;
    wire          q_empty = (q_wr == q_rd);
    wire          q_full  = ((q_wr + 1'b1) == q_rd);

    reg  usb_stb_d;
    wire btn_change = (btn_s[btn_idx] != btn_prev[btn_idx]);
    wire usb_pend   = (usb_key[10] != usb_stb_d);

    always @(posedge clk) begin
        if (reset) begin
            btn_s0 <= 8'd0; btn_s <= 8'd0; btn_prev <= 8'd0; btn_idx <= 3'd0;
            usb_stb_d <= 1'b0; q_wr <= {QW{1'b0}};
        end else begin
            btn_s0 <= buttons[7:0];
            btn_s  <= btn_s0;

            if (!q_full) begin
                if (btn_change) begin
                    queue[q_wr]       <= {btn_s[btn_idx], scancode(btn_idx)};
                    q_wr              <= q_wr + 1'b1;
                    btn_prev[btn_idx] <= btn_s[btn_idx];
                end else if (usb_pend) begin
                    queue[q_wr] <= {usb_key[9], usb_key[7:0]};
                    q_wr        <= q_wr + 1'b1;
                    usb_stb_d   <= usb_key[10];
                end else begin
                    btn_idx <= btn_idx + 3'd1;   // no event: advance scan (wraps 0..7)
                end
            end
        end
    end

    //
    // Frame: pop an event and write it as a make ([code]) or break ([0xF0, code]).
    // we is a one-cycle pulse; the !we guard in S_CODE separates the two break bytes.
    //
    localparam [1:0] S_IDLE = 2'd0, S_PREFIX = 2'd1, S_CODE = 2'd2;
    reg [1:0] fst;
    reg [7:0] f_code;

    always @(posedge clk) begin
        if (reset) begin
            fst <= S_IDLE; q_rd <= {QW{1'b0}}; we <= 1'b0; wdata <= 8'd0; f_code <= 8'd0;
        end else begin
            we <= 1'b0;   // default: one-cycle write pulses

            case (fst)
                S_IDLE: begin
                    if (!q_empty) begin
                        f_code <= queue[q_rd][7:0];
                        q_rd   <= q_rd + 1'b1;
                        fst    <= queue[q_rd][8] ? S_CODE : S_PREFIX;  // make vs break
                    end
                end

                S_PREFIX: begin              // break: emit 0xF0 first
                    if (!rx_full) begin
                        wdata <= 8'hF0;
                        we    <= 1'b1;
                        fst   <= S_CODE;
                    end
                end

                S_CODE: begin                // emit the key code
                    if (!we && !rx_full) begin
                        wdata <= f_code;
                        we    <= 1'b1;
                        fst   <= S_IDLE;
                    end
                end

                default: fst <= S_IDLE;
            endcase
        end
    end

endmodule
