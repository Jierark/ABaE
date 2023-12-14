`timescale 1ns/1ps
`default_nettype none
// Top level for cryptography, for testing
// so far this will synthesize for RSA-64
module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw,      
    input wire [3:0] btn,
    // input wire [3:0] pmoda,
    // input logic pmodb_sdi,
    // input wire uart_rxd,

    output logic [15:0] led,    
    output logic [2:0] rgb0,   
    output logic [2:0] rgb1  
    // output logic [3:0] pmodb
    // output wire pmoda_sdi, 
    // output logic uart_txd
    );
    assign led = sw; 

    // assign rgb0 = 0;  // Supress RGB LED's
    // assign rgb1 = 0; 

    logic sys_rst;
    assign sys_rst = btn[0];

    
    localparam UART_BAUD_RATE = 12_000_000;
    localparam MESSAGE_SIZE = 64;
    localparam HEADER_SIZE = 32;
    localparam PRIME_SIZE = MESSAGE_SIZE / 2;
    localparam KEY_SIZE = MESSAGE_SIZE;
    
    logic [PRIME_SIZE-1:0] p;
    logic [PRIME_SIZE-1:0] q;
    logic [KEY_SIZE-1:0] N;
    logic [16:0] e;
    logic [KEY_SIZE-1:0] d;
    logic [KEY_SIZE:0] R;
    assign R = 2**KEY_SIZE; // stays fixed
    assign e = 2**16 + 1;
    // TODO: make these a bit larger
    assign p = 211;
    assign q = 149;
    logic mult_valid_in, mult_valid_out, mult_busy;
    assign mult_valid_in = 1'b1; // change this

    multiplier #(.WIDTH(PRIME_SIZE))
     multiplier(.clk_in(clk_100mhz),
                .rst_in(sys_rst),
                .a_in(p),
                .b_in(q),
                .valid_in(mult_valid_in),
                .c_out(N),
                .valid_out(mult_valid_out),
                .busy_out(mult_busy)
                );
    logic markiplier_valid_in, markiplier_valid_out, markiplier_busy;
    logic [KEY_SIZE-1:0] totient;
    assign markiplier_valid_in = 1'b1; // change this
    multiplier #(.WIDTH(PRIME_SIZE))
     markiplier(.clk_in(clk_100mhz),
                .rst_in(sys_rst),
                .a_in(p-1),
                .b_in(q-1),
                .valid_in(markiplier_valid_in),
                .c_out(totient),
                .valid_out(markiplier_valid_out),
                .busy_out(markiplier_busy)
                );

    logic inv_valid_out,inv_error,inv_busy;
    modular_inverse #(.WIDTH(KEY_SIZE))
     modular_inverse(.clk_in(clk_100mhz),
                     .rst_in(sys_rst),
                     .a_in(e),
                     .base(totient),
                     .valid_in(markiplier_valid_out),
                     .b_out(d),
                     .valid_out(inv_valid_out),
                     .error_out(inv_error),
                     .busy_out(inv_busy)
                     );
    // both of these quantities may differ between boards.
    
    // probaby best to reuse the modular inverse module
    logic[KEY_SIZE-1:0] inv_modulo; // mod inverse of N mod R
    
    // Needs a divider smh
    logic[KEY_SIZE-1:0] one_montgomery_form; // R % N
    logic divider_valid_in, divider_valid_out, divider_error, divider_busy;
    divider #(.WIDTH(KEY_SIZE+1))
     divider(.clk_in(clk_100mhz),
             .rst_in(sys_rst),
             .dividend_in(N),
             .divider_in(R),
             .data_valid_in(divider_valid_in),
             .quotient_out(),
             .remainder_out(one_montgomery_form),
             .data_valid_out(divider_valid_out),
             .error_out(divider_error),
             .busy_out(divider_busy)
            );

    logic[KEY_SIZE-1:0] message;
    assign message = 16'hffff;
    logic[KEY_SIZE-1:0] ciphertext;
    logic encrypt_valid_in, encrypt_valid_out, encrypt_busy;
    assign encrypt_valid_in = 1'b1; // change this
    mod_exponent #(.WIDTH(MESSAGE_SIZE))
     encryption(.clk_in(clk_100mhz),
                .rst_in(sys_rst),
                .base(message),
                .exponent(e),
                .modulo(N),
                .inv_modulo(inv_modulo),
                .R(R),
                .start_product(one_montgomery_form),
                .valid_in(encrypt_valid_in),
                .c_out(ciphertext),
                .valid_out(encrypt_valid_out),
                .busy_out(encrypt_busy)
     );
    logic[KEY_SIZE-1:0] plaintext;
    logic decrypt_valid_out, decrypt_busy;
    mod_exponent #(.WIDTH(MESSAGE_SIZE))
    decryption(.clk_in(clk_100mhz),
               .rst_in(sys_rst),
               .base(ciphertext),
               .exponent(d),
               .modulo(N),
               .inv_modulo(inv_modulo),
               .R(R),
               .start_product(one_montgomery_form),
               .valid_in(encrypt_valid_out),
               .c_out(plaintext),
               .valid_out(decrypt_valid_out),
               .busy_out(decrypt_busy)
    );
    always_comb begin
        if (plaintext != message) begin
            rgb0 = 0;
            rgb1 = 0;
        end else begin
            rgb0 = 1;
            rgb1 = 1;
        end
    end
endmodule
`default_nettype wire