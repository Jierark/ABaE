`timescale 1ns/1ps
`default_nettype none

module mod_exponent #(parameter WIDTH = 512) (
    // Take a number and raise it to some power, mod another number
    // TODO: get a modular multiplication module that can work with this (montgomery multiplication perhaps?)
    // might just be able to build it into this...
    input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] base,
    input wire [WIDTH-1:0] exponent,
    input wire [WIDTH-1:0] modulo,
    input wire valid_in,
    output logic [WIDTH-1:0] c_out,
    output logic valid_out,
    output logic busy_out
    );
    typedef enum {IDLE=0,COMPUTING=1,DONE=2} states;
    states state;
    logic [WIDTH-1:0] running_product;
    logic [WIDTH-1:0] current_base;
    logic [$clog2(WIDTH)-1:0] current_index;
    always_ff @(posedge clk_in) begin
        // Declare a running product
        // start with base
        // compute base ^ (2^i) by squaring the previous value
        // if bit i is true --> multiply running product by base ^ (2^i)
        // Increment i
        // repeat until reach end
        if (rst_in) begin
            running_product <= 1;
            current_index <= 1;
            state <= IDLE;
            busy_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_in) begin
                        state <= COMPUTING;
                        running_product <= 1;
                        current_index <= 1; //skip the least significant bit since it doesn't affect the overall computation.
                        current_base <= base % modulo;
                        busy_out <= 1;
                    end
                end 
                COMPUTING: begin
                    if (current_index == WIDTH - 1) begin
                        state <= DONE;
                        c_out <= running_product;
                        valid_out <= 1;
                        busy_out <= 0;
                    end else begin
                        if (exponent[current_index] == 1) begin
                            running_product <= (running_product * current_base) % modulo;
                        end
                        current_index <= current_index + 1;
                        current_base <= (current_base * current_base) % modulo;
                    end
                end
                DONE: begin
                    state <= IDLE;
                    valid_out <= 0;
                end
            endcase
        end
    end
    
endmodule
`default_nettype wire ;