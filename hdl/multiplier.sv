`timescale 1ns/1ps
`default_nettype none

module multiplier #(parameter WIDTH=256) (
    // Take 2 WIDTH bit numbers and multiply them together.
    // Super naive 
    input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] a_in,
    input wire [WIDTH-1:0] b_in,
    input wire valid_in,
    output logic [WIDTH*2-1:0] c_out,
    output logic valid_out,
    output logic busy_out
    );
    typedef enum {IDLE=0,COMPUTING=1,DONE=2} fsm_state;
    fsm_state state;
    logic [$clog2(WIDTH)-1:0] index;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            c_out <= 0;
            index <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_in) begin
                        c_out <= 0;
                        index <= 0;
                        state <= COMPUTING;
                        busy_out <= 1;
                    end
                end
                COMPUTING: begin
                    if (index == WIDTH-1) begin
                        valid_out <= 1;
                        busy_out <= 0;
                        state <= DONE;
                    end else if (b_in[index] == 1'b1) begin
                        c_out <= c_out + (a_in << index); // Very naive way to compute a product
                    end
                    index <= index+1;
                end
                DONE: begin
                    valid_out <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire ;