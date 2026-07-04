//
// Analogue Pocket gamepad buttons -> PC/XT PS/2 keyboard
//
// Maps a fixed set of cont1_key buttons to PS/2 Set-2 scancodes and serialises
// them onto the device lines feeding CHIPSET's KFPS2KB receiver. The serialiser
// (ps2_device, from the MiSTer framework) is the shared output stage; this module
// is the button->scancode mapper and make/break generator around it.
//
// First-slice default map (assignable later via the interact menu):
//   D-pad -> arrows, A -> F8, B -> F2, X -> Enter, Y -> Esc.
// F2/F8 are printed as options by the boot ROM, so they give a visible response.
//
// KFPS2KB converts Set-2 -> XT, so codes here are Set-2 and a release is the
// two-byte break frame 0xF0 + code. XT has no separate arrow cluster, so the
// bare keypad codes (no 0xE0 prefix) are the correct arrows. Avoid F11 (0x78) /
// F12 (0x07): KFPS2KB consumes them internally for video-swap / pause.
//

module pocket_ps2_kbd (
    input        clk,          // clk_chipset (50 MHz) = ps2_device clk_sys
    input        reset,
    input [15:0] buttons,      // cont1_key (async - synchronised below)

    // host -> device lines from CHIPSET (idle high)
    input        ps2_clk_host,
    input        ps2_dat_host,

    // device -> host lines into CHIPSET (via its input synchronisers)
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
    // Serialiser: device -> host TX (scancodes out) + host -> device RX.
    // rx_full blocks TX writes while a host byte is pending; rd auto-drains
    // it so the BIOS keyboard-reset command (0xFF) can't wedge the FIFO.
    //
    reg  [7:0] wdata;
    reg        we;
    wire [8:0] rdata;
    wire       rx_full = rdata[8];

    // FIFO depth 8 (bits=3): a key event is at most 2 bytes and drains at
    // ~12.5 kHz, so 8 is ample. ps2_device forces the FIFO to logic, so a
    // smaller depth also keeps the ALM cost down. ps2_device stays pristine.
    ps2_device #(.PS2_FIFO_BITS(3)) u_ps2_device (
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
    // Synchronise the async controller buttons into the clk domain. Only
    // the low 8 bits are mapped: [0]=up [1]=down [2]=left [3]=right
    //                            [4]=A  [5]=B    [6]=X    [7]=Y
    //
    reg [7:0] btn_s0, btn_s;
    always @(posedge clk) begin
        btn_s0 <= buttons[7:0];
        btn_s  <= btn_s0;
    end

    // Fixed button-index -> Set-2 scancode map.
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
    // Make/break generator. Scans the 8 mapped bits; on a change emits a
    // make (code) or break (0xF0, code) frame into the serialiser. we is a
    // one-cycle pulse; the !we guard in S_CODE separates the two break bytes.
    //
    localparam [1:0] S_SCAN = 2'd0, S_PREFIX = 2'd1, S_CODE = 2'd2;

    reg [1:0] st;
    reg [2:0] idx;
    reg [7:0] prev_m;
    reg [7:0] code_r;

    always @(posedge clk) begin
        if (reset) begin
            st     <= S_SCAN;
            idx    <= 3'd0;
            prev_m <= 8'd0;
            code_r <= 8'd0;
            wdata  <= 8'd0;
            we     <= 1'b0;
        end else begin
            we <= 1'b0;   // default: one-cycle write pulses

            case (st)
                S_SCAN: begin
                    if (btn_s[idx] != prev_m[idx]) begin
                        code_r      <= scancode(idx);
                        prev_m[idx] <= btn_s[idx];
                        st          <= btn_s[idx] ? S_CODE : S_PREFIX;
                    end else begin
                        idx <= idx + 3'd1;   // wraps 0..7
                    end
                end

                S_PREFIX: begin              // break: emit 0xF0 first
                    if (!rx_full) begin
                        wdata <= 8'hF0;
                        we    <= 1'b1;
                        st    <= S_CODE;
                    end
                end

                S_CODE: begin                // emit the key code
                    if (!we && !rx_full) begin
                        wdata <= code_r;
                        we    <= 1'b1;
                        st    <= S_SCAN;
                    end
                end

                default: st <= S_SCAN;
            endcase
        end
    end

endmodule
