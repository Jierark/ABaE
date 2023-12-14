`timescale 1ns/1ps
`default_nettype none
// Top level for cryptography, for testing
// so far this will synthesize for RSA-64
module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw,      
    input wire [3:0] btn,
    input wire [3:0] pmoda,
    input wire pmodb_sdi,
    input wire uart_rxd,

    output logic [15:0] led,    
    output logic [2:0] rgb0,   
    output logic [2:0] rgb1, 
    output logic [3:0] pmodb,
    output logic pmoda_sdi, 
    output logic uart_txd
    );


    assign rgb0 = 0;  // Supress RGB LED's
    assign rgb1 = 0; 

    logic sys_rst;
    assign sys_rst = btn[0];

    
    localparam UART_BAUD_RATE = 12_000_000;
    localparam MESSAGE_SIZE = 64;
    localparam HEADER_SIZE = 32;
    localparam PRIME_SIZE = MESSAGE_SIZE / 2;
    localparam KEY_SIZE = MESSAGE_SIZE;

    // ------------------- Crypto SETUP ----------------- //
    
    logic [PRIME_SIZE-1:0] p;
    logic [PRIME_SIZE-1:0] q;
    logic [KEY_SIZE-1:0] N;
    logic [16:0] e;
    logic [KEY_SIZE-1:0] d;
    logic [KEY_SIZE:0] R;

    assign R = 2**KEY_SIZE; // stays fixed  // TODO TRY WRAPPING IN initial
    assign e = 2**16 + 1;
    // TODO: make these a bit larger
    assign p = 211;
    assign q = 149;

    // PRECOMPUTATIONS
    logic[KEY_SIZE-1:0] inv_modulo; // mod inverse of N mod R 
    assign inv_modulo = 64'h5733638FBA4C4C2F;  

    logic[KEY_SIZE-1:0] one_montgomery_form; // R % N
    assign one_montgomery_form = 10830; 
    // END PRECOMPUTATIONS

    // COMPUTE N
    logic mult_valid_in, mult_valid_out, mult_busy;
    assign mult_valid_in = 1'b1; // combinational
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

    // COMPUTE TOTIENT (optimization: compute off of N  //-> totient = (p - 1)(q - 1) = (pq - p - q + 1) = (N - p - q + 1))
    logic markiplier_valid_in, markiplier_valid_out, markiplier_busy;
    logic [KEY_SIZE-1:0] totient;
    assign markiplier_valid_in = 1'b1; // combinational
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

    // COMPUTE D (PRIVATE EXP)
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
    
    // // Needs a divider smh
    // logic[KEY_SIZE-1:0] one_montgomery_form; // R % N
    // assign one_montgomery_form = 10830;       // << Recompute w p/q
    // logic divider_valid_in, divider_valid_out, divider_error, divider_busy;
    // divider #(.WIDTH(KEY_SIZE+1))
    //  divider(.clk_in(clk_100mhz),
    //          .rst_in(sys_rst),
    //          .dividend_in(N),
    //          .divider_in(R),
    //          .data_valid_in(divider_valid_in),
    //          .quotient_out(),
    //          .remainder_out(one_montgomery_form),
    //          .data_valid_out(divider_valid_out),
    //          .error_out(divider_error),
    //          .busy_out(divider_busy)
    //         );


    // ------------------- Steady State ----------------- //

    // UART signals

    logic [MESSAGE_SIZE-1:0] message_received; 
    logic [HEADER_SIZE-1:0] header_received;

    logic [MESSAGE_SIZE-1:0] message_to_send_enc; 
    logic [MESSAGE_SIZE-1:0] message_to_send_dec; 
    logic [HEADER_SIZE-1:0] header_to_send;

    logic tx_valid_in;
    logic tx_ready_out;
    logic rx_valid_out;
    logic rx_ready_in;

    // SPI signals

    logic spi_ready_out;
    logic spi_valid_in;
    logic spi_ready_in;
    logic spi_valid_out;

    logic [MESSAGE_SIZE-1:0] spi_message_in;
    logic [HEADER_SIZE-1:0] spi_header_in;
    logic [MESSAGE_SIZE-1:0] spi_message_out;
    logic [HEADER_SIZE-1:0] spi_header_out;

    // Addnl buffers
    logic [HEADER_SIZE-1:0] spi_header_buffer;
    logic [HEADER_SIZE-1:0] uart_header_buffer;
    logic [MESSAGE_SIZE-1:0] raw_message_buffer;

    // Crypto signals
    
    logic encrypt_valid_in, encrypt_valid_out, encrypt_busy, encrypt_ready_in;
    logic decrypt_valid_in, decrypt_valid_out, decrypt_busy, decrypt_ready_in;

    logic [KEY_SIZE-1:0] message_to_encrypt; // temp intercept
    logic [KEY_SIZE-1:0] encrypted_message;  // temp intercept

    logic [KEY_SIZE-1:0] message_to_decrypt; // temp intercept
    logic [KEY_SIZE-1:0] decrypted_message;  // temp intercept

    //             PATHS
    // UART_RX -> ENCRYPT -> SPI_TX   (Encrypt Path)
    // SPI_RX  -> DECRYPT -> UART_TX  (Decrypt Path)
    //          |________/


    logic waiting_on_spi, waiting_on_tx, waiting_on_enc, waiting_on_dec;

    logic got_mult_output;
    logic got_mark_output;
    logic got_inv_output;

    logic finished_crypto_setup;

    assign finished_crypto_setup = got_mult_output && got_mark_output && got_inv_output;

    initial begin 
        tx_valid_in = 0;
        spi_valid_in = 0;
        encrypt_valid_in = 0;
        decrypt_valid_in = 0;

        rx_ready_in = 1;
        spi_ready_in = 1;
        encrypt_ready_in = 1;
        decrypt_ready_in = 1;

        waiting_on_spi = 0;
        waiting_on_tx = 0;
        waiting_on_enc = 0;
        waiting_on_dec = 0;

        got_mult_output = 0;
        got_mark_output = 0;
        got_inv_output = 0;

        // spi_message_in = 128'h000102030405060708090a0b0c0d0e0f;
        // spi_header_in = 32'b001111111_00000000_00000000_0000_1_1_1;
    end
    always_ff @(posedge clk_100mhz) begin 
        if (sys_rst) begin 
            tx_valid_in <= 0;
            spi_valid_in <= 0;
            encrypt_valid_in <= 0;
            decrypt_valid_in <= 0;

            rx_ready_in <= 1;
            spi_ready_in <= 1;
            encrypt_ready_in <= 1;
            decrypt_ready_in <= 1;
            
            waiting_on_spi <= 0;
            waiting_on_tx <= 0;
            waiting_on_enc <= 0;
            waiting_on_dec <= 0;

            got_mult_output <= 0;
            got_mark_output <= 0;
            got_inv_output <= 0;

            // spi_message_in <= 128'h000102030405060708090a0b0c0d0e0f;
            // spi_header_in <= 32'b001111111_00000000_00000000_0000_1_1_1;
                            // 32'b0011_1111_1000_0000_0000_0000_0000_0111;

            // message_to_send_enc <= 128'h000102030405060708090a0b0c0d0e0f;
            // message_to_send_dec <= 128'h000102030405060708090a0b0c0d0e0f;
            // header_to_send <= 32'b001111111_00000000_00000000_0000_1_1_1;
        end else begin
            // wait for CRYPTO SETUP 
            if (finished_crypto_setup) begin 
                if (mult_valid_out) begin 
                    got_mult_output <= 1;
                end
                if (markiplier_valid_out) begin
                    got_mark_output <= 1;
                end
                if (inv_valid_out) begin 
                    got_inv_output <= 1;
                end 
            end else begin
                // ----------- Encrypt path ------------ //
                // UART_RX -> Encrypt
                if (waiting_on_enc) begin
                    if (!encrypt_busy) begin 
                        waiting_on_enc <= 0;
                        rx_ready_in <= 1;
                    end 
                end else if (1) begin  // (rx_valid_out)
                    encrypt_valid_in <= 1;
                    // message_to_encrypt <= message_received;
                    // spi_header_buffer <= header_received;
                    message_to_encrypt <= 64'h0001020304050607;
                    spi_header_buffer <= 32'b001111111_00000000_00000000_0000_1_1_1;

                    if (encrypt_busy) begin 
                        waiting_on_enc <= 1;
                        rx_ready_in <= 0;
                    end
                end else begin 
                    encrypt_valid_in <= 0;
                end
                
                // Encrypt -> SPI_TX
                if (waiting_on_spi) begin
                    if (spi_ready_out) begin 
                        waiting_on_spi <= 0;
                        encrypt_ready_in <= 1;
                    end 
                end else if (encrypt_valid_out) begin  
                    spi_valid_in <= 1;
                    spi_message_in <= encrypted_message;
                    spi_header_in <= spi_header_buffer;

                    if (!spi_ready_out) begin 
                        waiting_on_spi <= 1;
                        encrypt_ready_in <= 0;
                    end
                end else begin 
                    spi_valid_in <= 0;
                end             

                // ----------- Decrypt path ------------ //
                // SPI_RX -> DECRYPT
                if (waiting_on_dec) begin 
                    if (!decrypt_busy) begin
                        waiting_on_dec <= 0;
                        spi_ready_in <= 1;
                    end
                end else if (spi_valid_out) begin
                    decrypt_valid_in <= 1;
                    message_to_decrypt <= spi_message_out;
                    raw_message_buffer <= spi_message_out;
                    uart_header_buffer <= spi_header_in;

                    if (decrypt_busy) begin
                        waiting_on_dec <= 1;
                        spi_ready_in <= 0;
                    end
                end else begin 
                    decrypt_valid_in <= 0;
                end

                // DECRYPT -> UART_TX
                if (waiting_on_tx) begin 
                    if (tx_ready_out) begin
                        waiting_on_tx <= 0;
                        decrypt_ready_in <= 1;
                    end
                end else if (decrypt_valid_out) begin
                    tx_valid_in <= 1;
                    message_to_send_enc <= raw_message_buffer;
                    message_to_send_dec <= decrypted_message;
                    header_to_send <= uart_header_buffer;

                    if (!tx_ready_out) begin
                        waiting_on_tx <= 1;
                        decrypt_ready_in <= 0;
                    end
                end else begin 
                    tx_valid_in <= 0;
                end
            end
        end
    end

    mod_exponent #(.WIDTH(MESSAGE_SIZE))
    encryption(.clk_in(clk_100mhz),
               .rst_in(sys_rst),
               .base(message_to_encrypt),
               .exponent(e),
               .modulo(N),
               .inv_modulo(inv_modulo),
               .R(R),
               .start_product(one_montgomery_form),
               .valid_in(encrypt_valid_in),
               .c_out(encrypted_message),
               .valid_out(encrypt_valid_out),
               .busy_out(encrypt_busy),
               .ready_in(encrypt_ready_in)
    );


   mod_exponent #(.WIDTH(MESSAGE_SIZE))
   decryption(.clk_in(clk_100mhz),
              .rst_in(sys_rst),
              .base(message_to_decrypt),
              .exponent(d),
              .modulo(N),
              .inv_modulo(inv_modulo),
              .R(R),
              .start_product(one_montgomery_form),
              .valid_in(decrypt_valid_in),
              .c_out(decrypted_message),
              .valid_out(decrypt_valid_out),
              .busy_out(decrypt_busy),
              .ready_in(decrypt_ready_in)
   );


    uart_controller #(.MESSAGE_SIZE(MESSAGE_SIZE),
                      .HEADER_SIZE(HEADER_SIZE),
                      .BAUD_RATE(UART_BAUD_RATE)) uart (
                        .clk_in(clk_100mhz),
                        .rst_in(sys_rst),

                        // Interface single-cycle signals
                        .ext_tx_valid_in(tx_valid_in),  // Message done decrypting
                        .ext_tx_ready_out(tx_ready_out), // Can receive new message
                        .ext_rx_valid_out(rx_valid_out), // New message available to encrypt
                        .ext_rx_ready_in(rx_ready_in),  // Encryption module ready

                        // tx data inputs
                        .tx_encrypted_in(message_to_send_enc),
                        .tx_decrypted_in(message_to_send_dec),
                        .tx_header_in(header_to_send),
                        .tx_mode_in(sw[1:0]),

                        // rx data outputs
                        .rx_message_out(message_received),
                        .rx_header_out(header_received),

                        // uart signals
                        .uart_rx_in(uart_rxd),
                        .uart_tx_out(uart_txd),

                        .debug(led[15:2])
                    );




    spi_controller #(.UART_BAUD_RATE(UART_BAUD_RATE),
                    .MESSAGE_SIZE(MESSAGE_SIZE),
                    .HEADER_SIZE(HEADER_SIZE)) spi (
                        .clk_in(clk_100mhz),
                        .rst_in(sys_rst),

                        // Interface single-cycle signals
                        .tx_ready_out(spi_ready_out), // Can receive new message
                        .tx_valid_in(spi_valid_in),  // Message done encrypting
                        .rx_ready_in(spi_ready_in),  // Decryption module ready
                        .rx_valid_out(spi_valid_out), // New message available to decrypt

                        // tx internals
                        .tx_message_in(spi_message_in), // Encrypted message to send
                        .tx_header_in(spi_header_in),

                        // tx wires - pmoda pins
                        .tx_data_out(pmodb[0]), // sdo
                        .tx_sel_out(pmodb[1]),  // ss
                        .tx_clk_out(pmodb[2]),  // clk
                        .tx_data_in(pmodb_sdi),  // sdi
                        .tx_key_req_out(pmodb[3]), // key_req

                        // rx internals
                        .rx_message_out(spi_message_out), // Raw message received
                        .rx_header_out(spi_header_out),

                        // rx wires - pmodb pins
                        .rx_data_in(pmoda[0]), // sdo
                        .rx_sel_in(pmoda[1]),  // ss
                        .rx_clk_in(pmoda[2]),  // clk
                        .rx_data_send(pmoda_sdi), // sdi
                        .rx_key_req_in(pmoda[3])  // key_req
    );
endmodule
`default_nettype wire