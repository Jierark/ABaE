`timescale 1ns/1ps
`default_nettype none

module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw,      
    input wire [3:0] btn,
    input wire [3:0] pmoda,
    input logic pmodb_sdi,
    input wire uart_rxd,

    output logic [15:0] led,    
    output logic [2:0] rgb0,   
    output logic [2:0] rgb1,   
    output logic [3:0] pmodb,
    output wire pmoda_sdi, 
    output logic uart_txd
    );
    // FPGA local IO ======================
    // assign led = sw; 

    assign rgb0 = 0;  // Supress RGB LED's
    assign rgb1 = 0; 

    logic sys_rst;
    assign sys_rst = btn[0];
    //--------------------------------------

    localparam UART_BAUD_RATE = 12_000_000;
    localparam MESSAGE_SIZE = 512;
    localparam HEADER_SIZE = 32;
    localparam KEY_SIZE = 512;
    localparam PRIME_SIZE = 256;

    logic [PRIME_SIZE-1:0] prime_p;
    logic [PRIME_SIZE-1:0] prime_q; 

    // keys - need to store local d, N (private key), and other's N (public key)
    //        we assume e is held constant at 2^16+1
    logic [KEY_SIZE-1:0] local_d;
    logic [KEY_SIZE-1:0] local_N;
    logic [KEY_SIZE-1:0] local_e;
    logic [KEY_SIZE-1:0] totient;
    logic [KEY_SIZE-1:0] local_N_inv;

    logic [KEY_SIZE-1:0] other_N;

    logic mod_inv_valid_in;
    logic mod_inv_valid_out;
    logic mod_inv_error_out;
    logic mod_inv_busy_out;
    logic mod_inv_ready_out;
    assign mod_inv_ready_out = ~mod_inv_busy_out;

    modular_inverse #(.WIDTH(MESSAGE_SIZE)) mod_inv (
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),
        .a_in(local_e),
        .base(totient),
        .b_out(local_d),
        .valid_in(mod_inv_valid_in),
        .valid_out(mod_inv_valid_out),
        .error_out(mod_inv_error_out),
        .busy_out(mod_inv_busy_out)
    );
    

    logic multiplier_valid_in;
    logic multiplier_valid_out;
    logic multiplier_busy_out;

    multiplier #(.WIDTH(PRIME_SIZE)) markiplier (
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),
        .a_in(prime_p),
        .b_in(prime_q),
        .valid_in(multiplier_valid_in),
        .c_out(local_N),
        .valid_out(multiplier_valid_out),
        .busy_out(multiplier_busy_out)
    );

    // Top-level FSM
    typedef enum {GEN_PRIMES, MULT_PRIMES, KEY_GENERATING, N_INV_GENERATING, KEY_NEGOTIATING, STEADY} top_level_states;
    top_level_states state;

    initial begin 
        state <= GEN_PRIMES;
    end

    always_ff @(posedge clk_in) begin 
        if (sys_rst) begin 
            state <= GEN_PRIMES;
        end else begin 
            case (state)
                GEN_PRIMES: begin
                    local_e <= 17'b1_0000_0000_0000_0001; // 2^16 + 1
                    prime_p <= 76169081874382125642238854425486407935401212829330169665605724967290745401687;
                    prime_q <= 98280911314746364071240728245300276656923070182035193988525871148250819055663;
                    multiplier_valid_in <= 1;
                    state <= MULT_PRIMES;
                end
                MULT_PRIMES: begin
                    multiplier_valid_in <= 0;
                    if (multiplier_valid_out) begin 
                        totient <= local_N - prime_p - prime_q + 1; //-> totient = (p - 1)(q - 1) = (pq - p - q + 1) = (N - p - q + 1)
                        mod_inv_valid_in <= 1;
                        mod_inv_delay <= 2;
                        state <= KEY_GENERATING;
                    end
                end
                KEY_GENERATING: begin 
                    mod_inv_valid_in <= 0;
                    if (mod_inv_ready_out) begin 
                        if (mod_inv_error_out || !mod_inv_valid_out) begin 
                            state <= GEN_PRIMES; // Something went wrong, restart
                        end else begin // valid_out
                            // N_INV 
                            // a_in : N 
                            // base : R -> 2^512 <- enormous
                            // b_out: N_inv
                            state <= N_INV_GENERATING;
                        end
                    end
                end
                N_INV_GENERATING: begin 
                    // TODO 
                end
                KEY_NEGOTIATING: begin
                end
                STEADY: begin
                end
            endcase
        end

        
    end
    
    uart_controller #(.MESSAGE_SIZE(MESSAGE_SIZE),
                      .HEADER_SIZE(HEADER_SIZE),
                      .BAUD_RATE(UART_BAUD_RATE)) uart (
                        .clk_in(clk_100mhz),
                        .rst_in(sys_rst),

                        // Interface single-cycle signals
                        .ext_tx_valid_in(),  // Message done decrypting
                        .ext_tx_ready_out(), // Can receive new message
                        .ext_rx_valid_out(), // New message available to encrypt
                        .ext_rx_ready_in(),  // Encryption module ready

                        // tx data inputs
                        .tx_encrypted_in(),
                        .tx_decrypted_in(),
                        .tx_header_in(),
                        .tx_mode_in(),

                        // rx data outputs
                        .rx_message_out(),
                        .rx_header_out(),

                        // uart signals
                        .uart_rx_in(uart_rxd),
                        .uart_tx_out(uart_txd)
                    );

    spi_controller #(.UART_BAUD_RATE(UART_BAUD_RATE),
                     .MESSAGE_SIZE(MESSAGE_SIZE),
                     .HEADER_SIZE(HEADER_SIZE)) spi (
                        .clk_in(clk_100mhz),
                        .rst_in(sys_rst),

                        // Interface single-cycle signals
                        .tx_ready_out(), // Can receive new message
                        .tx_valid_in(),  // Message done encrypting
                        .rx_ready_in(),  // Decryption module ready
                        .rx_valid_out(), // New message available to decrypt

                        // tx internals
                        .tx_message_in(), // Encrypted message to send
                        .tx_header_in(),

                        // tx wires - pmoda pins
                        .tx_data_out(pmoda[0]), // sdo
                        .tx_sel_out(pmoda[1]),  // ss
                        .tx_clk_out(pmoda[2]),  // clk
                        .tx_data_in(pmoda_sdi),  // sdi
                        .tx_key_req_out(pmoda[3]), // key_req

                        // rx internals
                        .rx_message_out(), // Raw message received
                        .rx_header_out(),

                        // rx wires - pmodb pins
                        .rx_data_in(pmodb[0]), // sdo
                        .rx_sel_in(pmodb[1]),  // ss
                        .rx_clk_in(pmodb[2]),  // clk
                        .rx_data_send(pmodb_sdi), // sdi
                        .rx_key_req_in(pmodb[3])  // key_req
                    );
endmodule
`default_nettype wire ;