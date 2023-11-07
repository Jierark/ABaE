`timescale 1ns/1ps
`default_nettype none
// Computes b such that a_in * b = 1 mod base for 512 bit numbers
module modular_inverse #(parameter WIDTH=512) (
    input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] a_in,
    input wire [WIDTH-1:0] base,
    input wire valid_in,
    output logic [WIDTH-1:0] b_out,
    output logic valid_out, 
    output logic error_out, // high when a_in has no modular inverse, mod base
    output logic busy_out
    );
    
    typedef enum {IDLE=0,BUSY=1,DONE=2} fsm_state; 
    fsm_state state;
    // Euclidean Algorithm logics
    logic [WIDTH-1:0] original_base; 
    logic signed [WIDTH-1:0] a_euclid, b_euclid;
    logic signed [WIDTH-1:0] x1, x2, y1, y2;
    logic busy, error;
    // Divider logics
    logic [WIDTH-1:0] quotient, remainder;
    logic divider_start, divider_end, divider_error, divider_busy;

    divider #(.WIDTH(WIDTH))
    divider(.clk_in(clk_in),
            .rst_in(rst_in),
            .dividend_in(a_euclid),
            .divisor_in(b_euclid),
            .data_valid_in(divider_start),
            .quotient_out(quotient),
            .remainder_out(remainder),
            .data_valid_out(divider_end),
            .error_out(divider_error),
            .busy_out(divider_busy)
    );

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            a_euclid <= 0;
            b_euclid <= 0;
            x1 <= 0;
            x2 <= 0;
            y1 <= 0;
            y2 <= 0;
            divider_start <= 0;
            busy <= 0;
            error <= 0;
        end else begin
            // Use Extended Euclidean algorithm to compute modular inverse
            case (state)
                IDLE: begin
                    if (valid_in) begin
                        a_euclid <= a_in;  
                        b_euclid <= base;
                        original_base <= base;
                        x1 <= 1;
                        x2 <= 0;
                        y1 <= 1;
                        y2 <= 0;
                        state <= BUSY;
                        divider_start <= 1; //Start dividing
                        busy <= 1;
                    end
                    valid_out <= 0;
                end 
                BUSY: begin
                    // TODO: Handle the case where there is no multiplicative inverse (which is when a is greater than 1)
                    if (b_euclid == 0) begin
                        if (a_euclid > 1) begin
                            error <= 0;
                            valid_out <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= DONE;
                            divider_start <= 0; 
                        end
                    end else if (divider_end && ~divider_busy) begin
                        // update values after divider finishes as so:
                        // (a, m) = (m, a - q * m)
                        // (x1, x2) = (x2, x1 - q * x2)
                        // (y1, y2) = (y2, y1 - q * y2)
                        a_euclid <= b_euclid;
                        b_euclid <= a_euclid - ($signed(quotient) * b_euclid);
                        x1 <= x2;
                        x2 <= x1 - ($signed(quotient) * x2);
                        y1 <= y2;
                        y2 <= y1 - ($signed(quotient) * y2);
                        divider_start <= 1;
                    end else if (divider_busy) begin //Divider is already working
                        divider_start <= 0;
                    end
                end
                DONE: begin
                    b_out <= (x1 < 0)? x1 + original_base: x1;
                    valid_out <= 1'b1;
                    state <= IDLE;
                end
            endcase            
        end
    end
    

endmodule
`default_nettype wire