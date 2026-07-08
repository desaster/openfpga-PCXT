//
// KFPS2KB_Byte_Accept
//
// Parallel Set-2 byte front-end for KFPS2KB. Accepts a scancode byte over a ready/valid
// handshake and presents it to the make-keycode stage as a one-cycle recieved_flag
// strobe. The irq gate waits for the guest to read the previous keycode; a fixed
// inter-byte pace (PACE) then holds kb_ready low across the guest's PB7 acknowledge, so
// the next byte is not masked by clear_keycode priority and a queued burst is metered
// into a paced catch-up instead of one flush. No framing, parity, or timeout.
//
module KFPS2KB_Byte_Accept (
    input   logic           clock,
    input   logic           reset,

    // Set-2 byte in
    input   logic   [7:0]   kb_byte,
    input   logic           kb_valid,
    output  logic           kb_ready,

    // Make-keycode stage
    input   logic           irq,
    output  reg     [7:0]   register,
    output  reg             recieved_flag,
    output  logic           error_flag
);
    localparam [15:0] PACE = 16'd44000;   // ~880 us at 50 MHz per byte
    reg     [15:0]  pace_cnt;
    reg             busy;                 // pacing out the last accepted byte

    assign  error_flag = 1'b0;
    assign  kb_ready   = ~busy & ~irq;

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            busy          <= 1'b0;
            pace_cnt      <= 16'd0;
            register      <= 8'h00;
            recieved_flag <= 1'b0;
        end
        else begin
            recieved_flag <= 1'b0;

            if (!busy) begin
                if (kb_valid & ~irq) begin
                    register      <= kb_byte;
                    recieved_flag <= 1'b1;
                    pace_cnt      <= PACE;
                    busy          <= 1'b1;
                end
            end
            else if (pace_cnt == 16'd0)
                busy <= 1'b0;
            else
                pace_cnt <= pace_cnt - 16'd1;
        end
    end

endmodule
