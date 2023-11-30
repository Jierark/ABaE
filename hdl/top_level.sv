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
    // assign led = sw; 

    assign rgb0 = 0;  // Supress RGB LED's
    assign rgb1 = 0; 

    logic sys_rst;
    assign sys_rst = btn[0];

    localparam UART_BAUD_RATE = 12_000_000;
    localparam MESSAGE_SIZE = 512;
    localparam HEADER_SIZE = 32;
    
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