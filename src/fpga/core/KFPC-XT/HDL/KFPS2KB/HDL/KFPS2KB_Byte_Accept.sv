//
// KFPS2KB_Byte_Accept
//
// Parallel Set-2 byte front-end for KFPS2KB: accepts a byte over ready/valid and strobes
// recieved_flag to the make-keycode stage. kb_ready stays low until PACE expires after the
// guest reads the keycode, so no byte is offered during the PB7 acknowledge, where
// clear_keycode priority would drop it. Bursts are paced, not flushed. No framing/parity.
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
            else if (irq)
                pace_cnt <= PACE;         // hold the pace off until the guest acks (irq low)
            else if (pace_cnt == 16'd0)
                busy <= 1'b0;
            else
                pace_cnt <= pace_cnt - 16'd1;
        end
    end

endmodule
