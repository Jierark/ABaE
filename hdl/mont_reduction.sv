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
     input wire valid_in,
     output logic [WIDTH-1:0] x_out,
     output logic valid_out,
     output logic busy_out
    );
    logic [WIDTH:0] R_length;
    assign R_length = WIDTH;

    logic signed [WIDTH:0] m;
    logic signed [WIDTH*2:0] t;

    logic mult_valid_in, mult_valid_out, mult_busy;
    logic [WIDTH:0] mult_a, mult_b;
    logic [WIDTH*2+1:0] mult_out;
    multiplier #(.WIDTH(WIDTH+1))
     multiplier(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .a_in(mult_a),
        .b_in(mult_b),
        .valid_in(mult_valid_in),
        .c_out(mult_out),
        .valid_out(mult_valid_out),
        .busy_out(mult_busy)
     );
    
    typedef enum  {IDLE=0,FIRST_OP=1,SECOND_OP=2,CHECK=3,DONE=4} fsm_state;
    fsm_state state;
    always_ff @(posedge clk_in) begin 
        if (rst_in) begin
            m <= 0;
            t <= 0;
            state <= IDLE;
            busy_out <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_in) begin
                        mult_a <= x_mont[WIDTH:0];
                        mult_b <= N_prime;
                        mult_valid_in <= 1'b1;
                        state <= FIRST_OP;
                        busy_out <= 1'b1;
                    end
                end 
                FIRST_OP: begin
                    if (mult_valid_out) begin
                        state <= SECOND_OP;
                        m <= mult_out[WIDTH:0];
                    end
                    mult_valid_in <= 1'b0;
                    // m <-- (x_mont mod R) *  N_prime mod R
                end
                SECOND_OP: begin
                    // t <-- (x_mont - m * N) // R (bit shift)
                    t <= ($signed({1'b0,x_mont}) - m * $signed({1'b0,N})) >>> R_length; //probably will need to rewrite this
                    t <= x_mont;
                    state <= CHECK;
                end
                CHECK: begin
                    if (t < 0) begin
                        x_out <= t + $signed({1'b0,N});
                    end else begin
                        x_out <= t[WIDTH-1:0];
                    end
                    valid_out <= 1'b1;
                    state <= DONE;
                    busy_out <= 1'b0;
                end
                DONE: begin
                    valid_out <= 1'b0;
                    state <= IDLE;
                end
            endcase       
        end
    end
endmodule
`default_nettype wire