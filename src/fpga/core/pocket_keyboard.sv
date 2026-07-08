//
// Pocket keyboard: merge controller buttons and a docked USB keyboard onto the
// single PS/2 device that CHIPSET's KFPS2KB receives.
//
// KFPS2KB is a real PS/2 serial device, so all input sources must share one
// serialised output. Three event producers - the cont1_key button map,
// hid_to_ps2 over the docked USB keyboard (cont3_*), and the on-screen virtual
// keyboard (vkb_*) - push key events into a small queue; a framer drains it,
// emitting each as a make ([code]) or break ([0xF0, code]), with a 0xE0 prefix for
// extended keys, into the ps2_device serialiser.
//
// Scancodes are Set-2 (KFPS2KB converts Set-2 -> XT).
//

module pocket_keyboard (
    input        clk,          // clk_chipset (50 MHz) = ps2_device clk_sys
    input        reset,
    input [15:0] buttons,      // cont1_key
    input        gamepad,      // 1 = joystick mode: buttons drive the game port, not keys
    input        osd_active,   // 1 = virtual keyboard open: suppress button typing
    input  [8:0] vkb_key,      // virtual-keyboard event: {make, Set-2 code}
    input        vkb_stb,      // toggles per firmware-emitted event
    input  [7:0] cfg_a,        // Set-2 scancode per face button (0 = unmapped)
    input  [7:0] cfg_b,
    input  [7:0] cfg_x,
    input  [7:0] cfg_y,
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
    // PS/2 bit-clock timebase: PS2DIV=2000 @ 50 MHz -> ~12.5 kHz, the rate
    // KFPS2KB_Shift_Register is proven against.
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
    // Serialiser. The TX FIFO drains slowly and has no full-guard, so the framer paces
    // its writes against occupancy (tx_credit). rx_full blocks TX writes while a host
    // byte is pending; rd auto-drains it so the BIOS reset command (0xFF) can't wedge it.
    //
    localparam PS2_FIFO_BITS = 4;   // TX FIFO depth = 2**bits
    reg  [7:0] wdata;
    reg        we;
    wire [8:0] rdata;
    wire       rx_full = rdata[8];
    wire       tx_empty;

    ps2_device #(.PS2_FIFO_BITS(PS2_FIFO_BITS)) u_ps2_device (
        .clk_sys     (clk),
        .wdata       (wdata),
        .we          (we),
        .ps2_clk     (clk_ps2),
        .ps2_clk_out (ps2_clk_dev),
        .ps2_dat_out (ps2_dat_dev),
        .tx_empty    (tx_empty),
        .ps2_clk_in  (ps2_clk_host),
        .ps2_dat_in  (ps2_dat_host),
        .rdata       (rdata),
        .rd          (rdata[8])
    );

    //
    // Source A: controller buttons. Synchronise cont1_key, then scan the mapped bits
    // one per clock: [0]=up [1]=down [2]=left [3]=right [4]=A [5]=B [6]=X [7]=Y,
    // [8]=Select [9]=Start. D-pad is fixed to the XT keypad arrows; A/B/X/Y take their
    // Set-2 code from the interact-menu config (cfg_*, 0 = unmapped); Select/Start are
    // fixed to Tab/Enter. Selected by the current scan index.
    //
    reg [9:0] btn_s0, btn_s, btn_prev, btn_mask;
    reg [3:0] btn_idx;

    // Key-mapped buttons before OSD gating: Start/Select always, plus (unless in
    // joystick mode) the D-pad and A/B/X/Y face buttons. btn_mask holds those still
    // down when the OSD closes so they cannot emit a make until released (closing the
    // keyboard with B would otherwise type B's mapped key into the guest).
    wire [9:0] btn_gated = {buttons[15], buttons[14], gamepad ? 8'd0 : buttons[7:0]};

    wire [7:0] cur_code = (btn_idx == 4'd0) ? 8'h75 :  // up     -> keypad 8
                          (btn_idx == 4'd1) ? 8'h72 :  // down   -> keypad 2
                          (btn_idx == 4'd2) ? 8'h6B :  // left   -> keypad 4
                          (btn_idx == 4'd3) ? 8'h74 :  // right  -> keypad 6
                          (btn_idx == 4'd4) ? cfg_a  :
                          (btn_idx == 4'd5) ? cfg_b  :
                          (btn_idx == 4'd6) ? cfg_x  :
                          (btn_idx == 4'd7) ? cfg_y  :
                          (btn_idx == 4'd8) ? 8'h0D :  // Select -> Tab
                                              8'h5A;   // Start  -> Enter

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
    // stalls rather than drop when the queue is full. The USB and virtual-keyboard
    // sources cannot stall; each presents a level strobe, so a pending event waits
    // for queue room.
    //
    localparam QW = 4;
    reg  [9:0]    queue [0:(1<<QW)-1];   // {ext, make, code[7:0]}
    reg  [QW-1:0] q_wr, q_rd;
    wire          q_empty = (q_wr == q_rd);
    wire          q_full  = ((q_wr + 1'b1) == q_rd);

    reg  usb_stb_d;
    reg  vkb_stb_d;
    wire btn_change = (btn_s[btn_idx] != btn_prev[btn_idx]);
    wire usb_pend   = (usb_key[10] != usb_stb_d);
    wire vkb_pend   = (vkb_stb != vkb_stb_d);

    always @(posedge clk) begin
        if (reset) begin
            btn_s0 <= 10'd0; btn_s <= 10'd0; btn_prev <= 10'd0; btn_mask <= 10'd0; btn_idx <= 4'd0;
            usb_stb_d <= 1'b0; vkb_stb_d <= 1'b0; q_wr <= {QW{1'b0}};
        end else begin
            // Start/Select stay live in joystick mode; D-pad + A/B/X/Y are gated off.
            // While the virtual keyboard is open every controller key is suppressed,
            // and any button still held when it closes stays masked until released.
            btn_s0   <= osd_active ? 10'd0 : (btn_gated & ~btn_mask);
            btn_s    <= btn_s0;
            btn_mask <= osd_active ? btn_gated : (btn_mask & btn_gated);

            if (!q_full) begin
                if (btn_change) begin
                    if (cur_code != 8'h00) begin        // 0 = unmapped: consume, emit nothing
                        queue[q_wr] <= {1'b0, btn_s[btn_idx], cur_code};
                        q_wr        <= q_wr + 1'b1;
                    end
                    btn_prev[btn_idx] <= btn_s[btn_idx];
                end else if (vkb_pend) begin            // Source C: on-screen keyboard
                    queue[q_wr] <= {1'b0, vkb_key};
                    q_wr        <= q_wr + 1'b1;
                    vkb_stb_d   <= vkb_stb;
                end else if (usb_pend) begin
                    queue[q_wr] <= {usb_key[8], usb_key[9], usb_key[7:0]};
                    q_wr        <= q_wr + 1'b1;
                    usb_stb_d   <= usb_key[10];
                end else begin
                    btn_idx <= (btn_idx == 4'd9) ? 4'd0 : btn_idx + 4'd1;   // advance scan 0..9
                end
            end
        end
    end

    //
    // Frame: pop an event and write it as a make ([code]) or break ([0xF0, code]), with a
    // 0xE0 prefix for extended keys. we is a one-cycle pulse; the !we guard separates bytes.
    //
    localparam [2:0] S_IDLE = 3'd0, S_PREFIX = 3'd1, S_CODE = 3'd2, S_E0 = 3'd3, S_SEQ = 3'd4;
    reg [2:0] fst;
    reg [7:0] f_code;
    reg       f_ext;    // current event is E0-extended
    reg       f_make;   // current event is a make (vs break)

    // Print Screen (0xE2) and Pause (0xE1) sentinels expand to these byte sequences; S_SEQ
    // walks one, a byte per pass, to the 0x00 terminator.
    localparam [4:0] PRTSC_MAKE = 5'd0, PRTSC_BREAK = 5'd5, PAUSE_SEQ = 5'd12;
    reg  [4:0] seq_addr;
    function [7:0] seq_rom;
        input [4:0] a;
        case (a)
            5'd0:  seq_rom = 8'hE0; // Print Screen make: E0 12 E0 7C
            5'd1:  seq_rom = 8'h12;
            5'd2:  seq_rom = 8'hE0;
            5'd3:  seq_rom = 8'h7C;
            5'd4:  seq_rom = 8'h00;
            5'd5:  seq_rom = 8'hE0; // Print Screen break: E0 F0 7C E0 F0 12
            5'd6:  seq_rom = 8'hF0;
            5'd7:  seq_rom = 8'h7C;
            5'd8:  seq_rom = 8'hE0;
            5'd9:  seq_rom = 8'hF0;
            5'd10: seq_rom = 8'h12;
            5'd11: seq_rom = 8'h00;
            5'd12: seq_rom = 8'hE1; // Pause (make-only): E1 14 77 E1 F0 14 F0 77
            5'd13: seq_rom = 8'h14;
            5'd14: seq_rom = 8'h77;
            5'd15: seq_rom = 8'hE1;
            5'd16: seq_rom = 8'hF0;
            5'd17: seq_rom = 8'h14;
            5'd18: seq_rom = 8'hF0;
            5'd19: seq_rom = 8'h77;
            5'd20: seq_rom = 8'h00;
            default: seq_rom = 8'h00;
        endcase
    endfunction

    // Outstanding TX FIFO bytes since it last drained (tx_empty); tx_room is clear once
    // this reaches the depth, withholding further writes.
    reg  [PS2_FIFO_BITS:0] tx_credit;
    wire tx_room = (tx_credit < ((1 << PS2_FIFO_BITS) - 1));

    //
    // Typematic repeat. A real PS/2 keyboard resends the held key's make after an
    // initial delay, then at a steady rate; there is no host to do that here, so
    // the framer synthesises it: it latches the last held key (armed on a make,
    // cleared on that key's break) and, while idle, reissues its make on the
    // delay/rate timer. Toggle-lock keys are excluded so a held lock cannot flip
    // repeatedly.
    //
    localparam [24:0] REP_DELAY = 25'd25_000_000;  // ~500 ms at 50 MHz
    localparam [24:0] REP_RATE  = 25'd5_000_000;   // ~100 ms -> ~10 cps
    reg  [7:0]  rep_code;
    reg         rep_ext;
    reg         rep_hold;
    reg         rep_started;
    reg  [24:0] rep_timer;
    wire [24:0] rep_thresh = rep_started ? REP_RATE : REP_DELAY;
    wire        rep_due    = rep_hold && (rep_timer >= rep_thresh);

    wire [9:0]  q_head     = queue[q_rd];
    wire        q_head_rep = (q_head[7:0] != 8'h58) &&  // not Caps Lock
                             (q_head[7:0] != 8'h77) &&  // not Num Lock
                             (q_head[7:0] != 8'h7E) &&  // not Scroll Lock
                             (q_head[7:0] != 8'h12) &&  // not left Shift
                             (q_head[7:0] != 8'h59) &&  // not right Shift
                             (q_head[7:0] != 8'h14) &&  // not Ctrl
                             (q_head[7:0] != 8'h11) &&  // not Alt
                             (q_head[7:0] != 8'hE1) &&  // not Pause (sequence)
                             (q_head[7:0] != 8'hE2);    // not Print Screen (sequence)

    always @(posedge clk) begin
        if (reset) begin
            fst <= S_IDLE; q_rd <= {QW{1'b0}}; we <= 1'b0; wdata <= 8'd0; f_code <= 8'd0;
            f_ext <= 1'b0; f_make <= 1'b0; seq_addr <= 5'd0; tx_credit <= 0;
            rep_code <= 8'd0; rep_ext <= 1'b0; rep_hold <= 1'b0; rep_started <= 1'b0; rep_timer <= 25'd0;
        end else begin
            we <= 1'b0;   // default: one-cycle write pulses

            // TX FIFO occupancy: one more byte per write, cleared on a full drain.
            if (tx_empty)
                tx_credit <= we ? 1'b1 : 1'b0;
            else if (we)
                tx_credit <= tx_credit + 1'b1;

            // Repeat timer counts while a key is held; S_IDLE restarts it on each
            // make or reissue.
            if (!rep_hold)
                rep_timer <= 25'd0;
            else if (rep_timer < rep_thresh)
                rep_timer <= rep_timer + 25'd1;

            case (fst)
                S_IDLE: begin
                    if (!q_empty) begin
                        f_code <= q_head[7:0];
                        f_ext  <= q_head[9];
                        f_make <= q_head[8];
                        q_rd   <= q_rd + 1'b1;
                        if (q_head[7:0] == 8'hE2) begin          // Print Screen sequence
                            seq_addr <= q_head[8] ? PRTSC_MAKE : PRTSC_BREAK;
                            fst      <= S_SEQ;
                        end else if (q_head[7:0] == 8'hE1) begin // Pause sequence (make-only)
                            seq_addr <= PAUSE_SEQ;
                            fst      <= q_head[8] ? S_SEQ : S_IDLE;
                        end else begin
                            fst      <= q_head[9] ? S_E0 : (q_head[8] ? S_CODE : S_PREFIX);
                        end
                        if (q_head[8]) begin                     // make: (re)arm repeat
                            rep_hold    <= q_head_rep;
                            rep_code    <= q_head[7:0];
                            rep_ext     <= q_head[9];
                            rep_started <= 1'b0;
                            rep_timer   <= 25'd0;
                        end else if (q_head[7:0] == rep_code) begin
                            rep_hold    <= 1'b0;                 // break of the held key
                        end
                    end else if (rep_due) begin                  // reissue the held make
                        f_code      <= rep_code;
                        f_ext       <= rep_ext;
                        f_make      <= 1'b1;
                        fst         <= rep_ext ? S_E0 : S_CODE;
                        rep_started <= 1'b1;
                        rep_timer   <= 25'd0;
                    end
                end

                S_E0: begin                  // extended: emit 0xE0 first
                    if (!rx_full && tx_room) begin
                        wdata <= 8'hE0;
                        we    <= 1'b1;
                        fst   <= f_make ? S_CODE : S_PREFIX;
                    end
                end

                S_PREFIX: begin              // break: emit 0xF0
                    if (!we && !rx_full && tx_room) begin
                        wdata <= 8'hF0;
                        we    <= 1'b1;
                        fst   <= S_CODE;
                    end
                end

                S_CODE: begin                // emit the key code
                    if (!we && !rx_full && tx_room) begin
                        wdata <= f_code;
                        we    <= 1'b1;
                        fst   <= S_IDLE;
                    end
                end

                S_SEQ: begin                 // walk a fixed scancode sequence (PrtSc/Pause)
                    if (!we && !rx_full && tx_room) begin
                        if (seq_rom(seq_addr) == 8'h00)
                            fst <= S_IDLE;
                        else begin
                            wdata    <= seq_rom(seq_addr);
                            we       <= 1'b1;
                            seq_addr <= seq_addr + 1'b1;
                        end
                    end
                end

                default: fst <= S_IDLE;
            endcase
        end
    end

endmodule
