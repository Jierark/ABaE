`timescale 1ns/1ps
`default_nettype none
// Montgomery reduction module, used to remove an extra factor of the constant R during multiplication, or to convert a number out of
// Montgomery form.
// Expected to take about 3 or 4 clock cycles
module mont_reduction #(parameter WIDTH=512)
    (input wire clk_in,
     input wire rst_in,
     input wire [WIDTH*2:0] x_mont,
     input wire [WIDTH-1:0] N,
     input wire [WIDTH:0] R, // R must be greater than the modulus N (really should be just 2**WIDTH, but eh)
     input wire [WIDTH-1:0] N_prime, // chosen such that N * N_prime = 1 mod R, this should be precomputed on startup
     output logic [WIDTH-1:0] x_out
    );
    logic [WIDTH:0] R_length;
    assign R_length = $clog2(R);

    logic signed [WIDTH:0] m;
    logic signed [WIDTH*2:0] t;

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin
            m <= 0;
            t <= 0;
        end else begin
            // m <-- (x_mont mod R) *  N_prime mod R
            // t <-- (x_mont - m * N) // R (bit shift)
            // if t < 0: t = t + N
            // return t             
            m <= ((x_mont % R) * N_prime) % R; // may need to change
            t <= ($signed({1'b0,x_mont}) - m * $signed({1'b0,N})) >>> R_length;
            if (t < 0) begin
                x_out <= t + $signed({1'b0,N});
            end else begin
                x_out <= t[WIDTH-1:0];
            end
        end
    end
endmodule
`default_nettype wire