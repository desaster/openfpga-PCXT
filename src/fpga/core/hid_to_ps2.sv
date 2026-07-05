//
// USB HID to PS/2 Set-2 scancode converter
//
// Converts an Analogue Pocket docked USB keyboard (6 concurrent HID usage codes
// + a modifier byte, packed into cont3_*) into ps2_key events
// {strobe, pressed, 1'b0, code[7:0]}. The HID-usage -> Set-2 mapping follows the
// public USB HID Keyboard and PS/2 Set-2 specifications.
//
// Within one report, modifier makes are emitted before key makes and key breaks
// before modifier breaks, so a chord holds its modifier around the key.
//

module hid_to_ps2
(
	input             clk,
	input             reset,
	input      [31:0] joy,     // cont3_joy
	input      [15:0] trig,    // cont3_trig
	input       [7:0] mods,    // modifier byte
	output reg [10:0] ps2_key  // {strobe, pressed, 1'b0, code[7:0]}
);

reg [47:0] prev_raw;
reg  [7:0] prev_mods;

wire [47:0] curr_raw = {joy, trig};
wire data_changed = (curr_raw != prev_raw) || (mods != prev_mods);

reg [47:0] scan_curr, scan_prev;
reg  [7:0] scan_mcurr, scan_mprev;

function automatic [7:0] slot_code;
	input [47:0] pdata;
	input [2:0]  idx;
	case (idx)
		0: slot_code = pdata[47:40];
		1: slot_code = pdata[39:32];
		2: slot_code = pdata[31:24];
		3: slot_code = pdata[23:16];
		4: slot_code = pdata[15:8];
		5: slot_code = pdata[7:0];
		default: slot_code = 8'h00;
	endcase
endfunction

function automatic code_in;
	input [7:0]  code;
	input [47:0] pdata;
	code_in = (code != 8'h00) && (
		code == pdata[47:40] || code == pdata[39:32] ||
		code == pdata[31:24] || code == pdata[23:16] ||
		code == pdata[15:8]  || code == pdata[7:0]);
endfunction

// HID usage code to PS/2 Set 2 scancode
function automatic [7:0] hid2ps2;
	input [7:0] h;
	case (h)
		8'h04: hid2ps2 = 8'h1C; // A
		8'h05: hid2ps2 = 8'h32; // B
		8'h06: hid2ps2 = 8'h21; // C
		8'h07: hid2ps2 = 8'h23; // D
		8'h08: hid2ps2 = 8'h24; // E
		8'h09: hid2ps2 = 8'h2B; // F
		8'h0A: hid2ps2 = 8'h34; // G
		8'h0B: hid2ps2 = 8'h33; // H
		8'h0C: hid2ps2 = 8'h43; // I
		8'h0D: hid2ps2 = 8'h3B; // J
		8'h0E: hid2ps2 = 8'h42; // K
		8'h0F: hid2ps2 = 8'h4B; // L
		8'h10: hid2ps2 = 8'h3A; // M
		8'h11: hid2ps2 = 8'h31; // N
		8'h12: hid2ps2 = 8'h44; // O
		8'h13: hid2ps2 = 8'h4D; // P
		8'h14: hid2ps2 = 8'h15; // Q
		8'h15: hid2ps2 = 8'h2D; // R
		8'h16: hid2ps2 = 8'h1B; // S
		8'h17: hid2ps2 = 8'h2C; // T
		8'h18: hid2ps2 = 8'h3C; // U
		8'h19: hid2ps2 = 8'h2A; // V
		8'h1A: hid2ps2 = 8'h1D; // W
		8'h1B: hid2ps2 = 8'h22; // X
		8'h1C: hid2ps2 = 8'h35; // Y
		8'h1D: hid2ps2 = 8'h1A; // Z

		8'h1E: hid2ps2 = 8'h16; // 1
		8'h1F: hid2ps2 = 8'h1E; // 2
		8'h20: hid2ps2 = 8'h26; // 3
		8'h21: hid2ps2 = 8'h25; // 4
		8'h22: hid2ps2 = 8'h2E; // 5
		8'h23: hid2ps2 = 8'h36; // 6
		8'h24: hid2ps2 = 8'h3D; // 7
		8'h25: hid2ps2 = 8'h3E; // 8
		8'h26: hid2ps2 = 8'h46; // 9
		8'h27: hid2ps2 = 8'h45; // 0

		8'h28: hid2ps2 = 8'h5A; // enter
		8'h29: hid2ps2 = 8'h76; // esc
		8'h2A: hid2ps2 = 8'h66; // bksp
		8'h2B: hid2ps2 = 8'h0D; // tab
		8'h2C: hid2ps2 = 8'h29; // space
		8'h2D: hid2ps2 = 8'h4E; // -
		8'h2E: hid2ps2 = 8'h55; // =
		8'h2F: hid2ps2 = 8'h54; // [
		8'h30: hid2ps2 = 8'h5B; // ]
		8'h31: hid2ps2 = 8'h5D; // backslash
		8'h64: hid2ps2 = 8'h5D; // ISO key near LShift -> backslash
		8'h33: hid2ps2 = 8'h4C; // ;
		8'h34: hid2ps2 = 8'h52; // '
		8'h35: hid2ps2 = 8'h0E; // `
		8'h36: hid2ps2 = 8'h41; // ,
		8'h37: hid2ps2 = 8'h49; // .
		8'h38: hid2ps2 = 8'h4A; // /
		8'h39: hid2ps2 = 8'h58; // capslock

		8'h3A: hid2ps2 = 8'h05; // F1
		8'h3B: hid2ps2 = 8'h06; // F2
		8'h3C: hid2ps2 = 8'h04; // F3
		8'h3D: hid2ps2 = 8'h0C; // F4
		8'h3E: hid2ps2 = 8'h03; // F5
		8'h3F: hid2ps2 = 8'h0B; // F6
		8'h40: hid2ps2 = 8'h83; // F7
		8'h41: hid2ps2 = 8'h0A; // F8
		8'h42: hid2ps2 = 8'h01; // F9
		8'h43: hid2ps2 = 8'h09; // F10
		8'h44: hid2ps2 = 8'h78; // F11
		8'h45: hid2ps2 = 8'h07; // F12

		8'h4A: hid2ps2 = 8'h6C; // home
		8'h4B: hid2ps2 = 8'h7D; // pgup
		8'h4C: hid2ps2 = 8'h71; // del
		8'h4F: hid2ps2 = 8'h74; // right
		8'h50: hid2ps2 = 8'h6B; // left
		8'h51: hid2ps2 = 8'h72; // down
		8'h52: hid2ps2 = 8'h75; // up

		default: hid2ps2 = 8'h00;
	endcase
endfunction

function automatic [7:0] mod2ps2;
	input [2:0] idx;
	case (idx)
		3'd0: mod2ps2 = 8'h14; // lctrl
		3'd1: mod2ps2 = 8'h12; // lshift
		3'd2: mod2ps2 = 8'h11; // lalt
		3'd3: mod2ps2 = 8'h00; // lgui
		3'd4: mod2ps2 = 8'h14; // rctrl
		3'd5: mod2ps2 = 8'h59; // rshift
		3'd6: mod2ps2 = 8'h11; // ralt
		3'd7: mod2ps2 = 8'h00; // rgui
	endcase
endfunction

wire [7:0] curr_at  = slot_code(scan_curr, slot);
wire [7:0] prev_at  = slot_code(scan_prev, slot);
wire [7:0] ps2_curr = hid2ps2(curr_at);
wire [7:0] ps2_prev = hid2ps2(prev_at);
wire [7:0] ps2_mod  = mod2ps2(slot);

wire is_new_press   = (curr_at != 0) && (ps2_curr != 0) && !code_in(curr_at, scan_prev);
wire is_new_release = (prev_at != 0) && (ps2_prev != 0) && !code_in(prev_at, scan_curr);
wire is_mod_press   = scan_mcurr[slot] && !scan_mprev[slot] && (ps2_mod != 0);
wire is_mod_release = !scan_mcurr[slot] && scan_mprev[slot] && (ps2_mod != 0);

localparam S_IDLE     = 3'd0,
           S_MPRESS   = 3'd1,
           S_PRESS    = 3'd2,
           S_RELEASE  = 3'd3,
           S_MRELEASE = 3'd4;

reg [2:0] state;
reg [2:0] slot;

always @(posedge clk) begin
	if (reset) begin
		state     <= S_IDLE;
		slot      <= 0;
		ps2_key   <= 0;
		prev_raw  <= 0;
		prev_mods <= 0;
	end else begin
		case (state)

		S_IDLE: begin
			if (data_changed) begin
				scan_curr  <= curr_raw;
				scan_prev  <= prev_raw;
				scan_mcurr <= mods;
				scan_mprev <= prev_mods;
				prev_raw   <= curr_raw;
				prev_mods  <= mods;
				state      <= S_MPRESS;
				slot       <= 0;
			end
		end

		S_MPRESS: begin
			if (is_mod_press)
				ps2_key <= {~ps2_key[10], 1'b1, 1'b0, ps2_mod};
			if (slot == 3'd7) begin
				state <= S_PRESS;
				slot  <= 0;
			end else
				slot <= slot + 1'd1;
		end

		S_PRESS: begin
			if (is_new_press)
				ps2_key <= {~ps2_key[10], 1'b1, 1'b0, ps2_curr};
			if (slot == 3'd5) begin
				state <= S_RELEASE;
				slot  <= 0;
			end else
				slot <= slot + 1'd1;
		end

		S_RELEASE: begin
			if (is_new_release)
				ps2_key <= {~ps2_key[10], 1'b0, 1'b0, ps2_prev};
			if (slot == 3'd5) begin
				state <= S_MRELEASE;
				slot  <= 0;
			end else
				slot <= slot + 1'd1;
		end

		S_MRELEASE: begin
			if (is_mod_release)
				ps2_key <= {~ps2_key[10], 1'b0, 1'b0, ps2_mod};
			if (slot == 3'd7)
				state <= S_IDLE;
			else
				slot <= slot + 1'd1;
		end

		default: state <= S_IDLE;

		endcase
	end
end

endmodule
