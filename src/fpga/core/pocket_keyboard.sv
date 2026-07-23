//
// Pocket keyboard: merge controller buttons, a docked USB keyboard, and the
// on-screen virtual keyboard into one Set-2 scancode byte stream for CHIPSET's
// KFPS2KB.
//
// Three event producers - the cont1_key button map, hid_to_ps2 over the docked
// USB keyboard (cont3_*), and the virtual keyboard (vkb_*) - push key events into
// a small queue; a framer drains it, handing KFPS2KB each byte over a ready/valid
// handshake as a make ([code]) or break ([0xF0, code]), with a 0xE0 prefix for
// extended keys. kb_ready paces one byte at a time.
//
// Scancodes are Set-2 (KFPS2KB converts Set-2 -> XT).
//

module pocket_keyboard #(
    parameter clk_rate = 28'd50000000   // clk frequency in Hz, sets the typematic timing
) (
    input        clk,          // clk_chipset
    input        reset,
    input [15:0] buttons,      // cont1_key
    input        gamepad,      // 1 = joystick mode: buttons drive the game port, not keys
    input        osd_active,   // 1 = an overlay (OSD or credits) is up: suppress button typing
    input  [8:0] vkb_key,      // virtual-keyboard event: {make, Set-2 code}
    input        vkb_stb,      // toggles per firmware-emitted event
    input [16*9-1:0] key_cfg,  // per-control {ext, Set-2 code} file; ids 4-10 are the buttons (code 0 = unmapped/function)
    input [31:0] cont3_joy,    // docked USB: HID usage codes 1-4
    input [15:0] cont3_trig,   // docked USB: HID usage codes 5-6
    input [15:0] cont3_key,    // docked USB: modifier bits (byte [15:8])

    // Set-2 scancode byte to CHIPSET's KFPS2KB; kb_ready gates one byte at a time
    output [7:0] kb_byte,
    output       kb_valid,
    input        kb_ready,

    // Last docked-keyboard make {ext, code} for the softcore key picker; kbd_stb toggles per make.
    output reg [7:0] kbd_code,
    output reg       kbd_ext,
    output reg       kbd_stb
);

    //
    // Source A: controller buttons. Synchronise cont1_key, then scan the mapped bits
    // one per clock: [0]=up [1]=down [2]=left [3]=right [4]=A [5]=B [6]=X [7]=Y, [8]=Select
    // [9]=Start [10]=R1. Each takes its {ext, Set-2 code} from key_cfg[btn_idx] (code 0 = unmapped):
    // the D-pad from the chosen direction preset, the buttons from their bindings. A button bound to
    // an OSD function reads code 0 here, and the softcore runs the function instead.
    //
    reg [10:0] btn_s0, btn_s, btn_prev, btn_mask;
    reg  [3:0] btn_idx;

    // Key-mapped buttons before OSD gating: Select/Start and R1 always, plus (unless in joystick
    // mode) the D-pad and A/B/X/Y face buttons. btn_mask holds those still down when the OSD closes
    // so they cannot emit a make until released (closing the keyboard with B would otherwise type
    // B's mapped key into the guest).
    wire [10:0] btn_gated = {buttons[9], buttons[15], buttons[14], gamepad ? 8'd0 : buttons[7:0]};

    wire [8:0] cur_key = key_cfg[btn_idx*9 +: 9];  // 0-3 D-pad preset, 4-10 button bindings

    //
    // Source B: docked USB keyboard. Synchronise cont3_* from the clk_74a bridge domain,
    // then hand hid_to_ps2 the report only after it has held steady for a few cycles.
    // A raw per-bit crossing can latch a key transition mid-settle (bits resolving
    // old-or-new independently) or straddle the bridge's non-atomic per-bus update; since
    // hid_to_ps2 edge-detects the report, such a transient would post a phantom scancode.
    //
    reg [31:0] joy_s0, joy_s1, joy_s;
    reg [15:0] trig_s0, trig_s1, trig_s;
    reg [15:0] key_s0, key_s1, key_s;
    reg  [2:0] rpt_stable;
    wire       rpt_steady = (joy_s0 == joy_s1) && (trig_s0 == trig_s1) && (key_s0 == key_s1);

    always @(posedge clk) begin
        joy_s0  <= cont3_joy;  joy_s1  <= joy_s0;
        trig_s0 <= cont3_trig; trig_s1 <= trig_s0;
        key_s0  <= cont3_key;  key_s1  <= key_s0;
        if (!rpt_steady)
            rpt_stable <= 3'd0;
        else if (rpt_stable != 3'd4)
            rpt_stable <= rpt_stable + 3'd1;
        else begin
            joy_s  <= joy_s1;
            trig_s <= trig_s1;
            key_s  <= key_s1;
        end
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

    // Softcore key-picker tap: latch the last docked-keyboard make {ext, code}, toggling kbd_stb so
    // the firmware can change-detect it. Independent of the queue and the OSD gate below, so it
    // fires even while a make is being held out of the guest.
    reg cap_stb_d;
    always @(posedge clk) begin
        if (reset) begin
            cap_stb_d <= 1'b0; kbd_code <= 8'd0; kbd_ext <= 1'b0; kbd_stb <= 1'b0;
        end else if (usb_key[10] != cap_stb_d) begin
            cap_stb_d <= usb_key[10];
            if (usb_key[9]) begin   // make only
                kbd_code <= usb_key[7:0];
                kbd_ext  <= usb_key[8];
                kbd_stb  <= ~kbd_stb;
            end
        end
    end

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
    // One mailbox per source, signalled by a toggle: if hid_to_ps2 emits on two
    // consecutive cycles while the queue is full, both are missed (the toggle nets out).
    // USB is serviced first below, being the only source that cannot wait; buttons
    // rescan and the VKB is firmware-paced.
    wire usb_pend   = (usb_key[10] != usb_stb_d);
    wire vkb_pend   = (vkb_stb != vkb_stb_d);

    always @(posedge clk) begin
        if (reset) begin
            btn_s0 <= 11'd0; btn_s <= 11'd0; btn_prev <= 11'd0; btn_mask <= 11'd0; btn_idx <= 4'd0;
            usb_stb_d <= 1'b0; vkb_stb_d <= 1'b0; q_wr <= {QW{1'b0}};
        end else begin
            // OSD open: gate all keys and hold still-down buttons masked until released. The mask is
            // also what makes a live key_cfg rebind safe: a rebind only happens with the OSD open, and
            // a held button cannot emit until release, so a make and its break never straddle the
            // change with mismatched codes and leave a key stuck.
            btn_s0   <= osd_active ? 11'd0 : (btn_gated & ~btn_mask);
            btn_s    <= btn_s0;
            btn_mask <= osd_active ? btn_gated : (btn_mask & btn_gated);

            if (!q_full) begin
                if (usb_pend) begin                     // docked USB keyboard: cannot wait
                    usb_stb_d <= usb_key[10];           // consume the event
                    // Hold docked makes out of the guest while an overlay is up (the key picker
                    // still gets them via the tap above); breaks pass so a key held across the
                    // overlay opening is released cleanly.
                    if (!(osd_active && usb_key[9])) begin
                        queue[q_wr] <= {usb_key[8], usb_key[9], usb_key[7:0]};
                        q_wr        <= q_wr + 1'b1;
                    end
                end else if (vkb_pend) begin            // Source C: on-screen keyboard
                    queue[q_wr] <= {1'b0, vkb_key};
                    q_wr        <= q_wr + 1'b1;
                    vkb_stb_d   <= vkb_stb;
                end else if (btn_change) begin
                    if (cur_key[7:0] != 8'h00) begin    // code 0 = unmapped: consume, emit nothing
                        queue[q_wr] <= {cur_key[8], btn_s[btn_idx], cur_key[7:0]};
                        q_wr        <= q_wr + 1'b1;
                    end
                    btn_prev[btn_idx] <= btn_s[btn_idx];
                end else begin
                    btn_idx <= (btn_idx == 4'd10) ? 4'd0 : btn_idx + 4'd1;  // advance scan 0..10
                end
            end
        end
    end

    //
    // Frame: pop an event and emit it as a make ([code]) or break ([0xF0, code]), with a
    // 0xE0 prefix for extended keys, one byte per kb_ready handshake.
    //
    localparam [2:0] S_IDLE = 3'd0, S_PREFIX = 3'd1, S_CODE = 3'd2, S_E0 = 3'd3, S_SEQ = 3'd4;
    reg [2:0] fst;
    reg [7:0] f_code;
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

    //
    // Typematic repeat. A real PS/2 keyboard resends the held key's make after an
    // initial delay, then at a steady rate; there is no host to do that here, so
    // the framer synthesises it: it latches the last held key (armed on a make,
    // cleared on that key's break) and, while idle, reissues its make on the
    // delay/rate timer. Toggle-lock keys are excluded so a held lock cannot flip
    // repeatedly.
    //
    localparam [24:0] REP_DELAY = clk_rate / 2;    // ~500 ms before the first repeat
    localparam [24:0] REP_RATE  = clk_rate / 10;   // ~100 ms -> ~10 cps
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

    // Byte handed to KFPS2KB, valid in the emit states; kb_ready completes the
    // handshake and advances the framer.
    assign kb_valid = (fst == S_E0) || (fst == S_PREFIX) || (fst == S_CODE) ||
                      (fst == S_SEQ && seq_rom(seq_addr) != 8'h00);
    assign kb_byte  = (fst == S_E0)     ? 8'hE0 :
                      (fst == S_PREFIX)  ? 8'hF0 :
                      (fst == S_SEQ)     ? seq_rom(seq_addr) :
                                           f_code;

    always @(posedge clk) begin
        if (reset) begin
            fst <= S_IDLE; q_rd <= {QW{1'b0}}; f_code <= 8'd0;
            f_make <= 1'b0; seq_addr <= 5'd0;
            rep_code <= 8'd0; rep_ext <= 1'b0; rep_hold <= 1'b0; rep_started <= 1'b0; rep_timer <= 25'd0;
        end else begin
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
                        f_make      <= 1'b1;
                        fst         <= rep_ext ? S_E0 : S_CODE;
                        rep_started <= 1'b1;
                        rep_timer   <= 25'd0;
                    end
                end

                S_E0: begin                  // extended: emit 0xE0 first
                    if (kb_ready)
                        fst <= f_make ? S_CODE : S_PREFIX;
                end

                S_PREFIX: begin              // break: emit 0xF0
                    if (kb_ready)
                        fst <= S_CODE;
                end

                S_CODE: begin                // emit the key code
                    if (kb_ready)
                        fst <= S_IDLE;
                end

                S_SEQ: begin                 // walk a fixed scancode sequence (PrtSc/Pause)
                    if (seq_rom(seq_addr) == 8'h00)
                        fst <= S_IDLE;
                    else if (kb_ready)
                        seq_addr <= seq_addr + 1'b1;
                end

                default: fst <= S_IDLE;
            endcase
        end
    end

endmodule
