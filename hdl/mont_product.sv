`timescale 1ns/1ps
`default_nettype none
// Montgomery reduction module, used to remove an extra factor of the constant R during multiplication, or to convert a number out of
// Montgomery form.
module mont_reduction #(parameter WIDTH=512)
    (input wire clk_in,
     input wire rst_in,
     input wire [WIDTH-1:0] x_mont,
     input wire [WIDTH-1:0] N,
     input wire [WIDTH:0] R, // R must be greater than the modulus N (really should be just 2**WIDTH, but eh)
     input wire [WIDTH-1:0] N_prime, // chosen such that N * N_prime = 1 mod R, this should be precomputed on startup
     output logic [WIDTH-1:0] x_out
    );
    logic [WIDTH-1:0] m;
    signed logic [WIDTH:0]
    always_ff @posedge (clk_in) begin
    // m <-- (x_mont mod R) *  N_prime mod R
        m <= (x_mont % R) * N_prime % R
        t <= (x_mont - m * N) / R
    // t <-- (x_mont - m * N) // R (bit shift)
    // if t < 0: t = t + N
    // return t 
    end

endmodule

module mod_multiplier #(parameter WIDTH = 512,
                        parameter R = 64) // r is the number of bits to shift by
    (input wire clk_in,
     input wire rst_in,
     input wire [WIDTH+R-1:0] a_in, 
     input wire [WIDTH+R-1:0] b_in,
     input wire [WIDTH-1:0] modulo,
     output logic [WIDTH-1:0] c_out
    ); // a_in, b_in are provided to be in montgomery form. the modulo and output can be left as [Width] bit numbers.
    logic [(WIDTH+R)*2-1:0] product;
    typedef enum {IDLE=0,  } fsm_state;
    always_ff @posedge (clk_in) begin
        
    end

endmodule
`default_nettype wire