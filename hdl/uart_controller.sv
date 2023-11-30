`timescale 1ns / 1ps
`default_nettype none 
module uart_controller #(parameter MESSAGE_SIZE = 512, 
                         parameter HEADER_SIZE = 32,
                         parameter BAUD_RATE = 12_000_000) (
    input clk_in,
    input rst_in, 


    // uart_tx params
    input wire ext_tx_valid_in,    // HIGH when new full message entered
    output logic ext_tx_ready_out, // HIGH when ready to receive new message
    input wire [MESSAGE_SIZE-1:0] tx_encrypted_in,
    input wire [MESSAGE_SIZE-1:0] tx_decrypted_in,
    input wire [HEADER_SIZE-1:0] tx_header_in,
    input wire [1:0] tx_mode_in,          // 2'b00 = MIXED, 2'b01 = RAW, 2'b10 = ENC
    

    // uart_rx params
    output logic ext_rx_valid_out, // HIGH when new full message out
    input logic ext_rx_ready_in,   // HIGH when downstream module can receive new message
    output logic [MESSAGE_SIZE-1:0] rx_message_out,
    output logic [HEADER_SIZE-1:0] rx_header_out,

    // uart signals
    input uart_rx_in, 
    output uart_tx_out
);

    uart_tx #(.BAUD_RATE(BAUD_RATE)) tx (
                .clk_in(clk_in),
                .rst_in(rst_in),
                .valid_in(),
                .byte_in(),
                .uart_tx_out(uart_tx_out),
                .ready_out()
            );

    uart_tx_bridge #(.MESSAGE_SIZE(MESSAGE_SIZE)
                     .HEADER_SIZE(HEADER_SIZE)) tx_bridge(
                        .clk_in(clk_in),
                        .rst_in(rst_in),
                        .message_in(),
                        .header_in(),
                        .ctrl_valid_in(),
                        .bdge_ready_out(),
                        .ll_ready_in(),
                        .ll_byte_out(),
                        .ll_valid_out()
                    );

    uart_rx #(.BAUD_RATE(BAUD_RATE)) rx (
                .clk_in(clk_in),
                .rst_in(rst_in),
                .uart_rx_in(uart_rx_in),
                .byte_out(),
                .ready_in(),
                .valid_out()
            );

    uart_rx_bridge #(.MESSAGE_SIZE(MESSAGE_SIZE)
                     .HEADER_SIZE(HEADER_SIZE)) rx_bridge(
                        .clk_in(clk_in),
                        .rst_in(rst_in),
                        .message_out(),
                        .header_out(),
                        .ctrl_ready_in(),
                        .bdge_valid_out(),
                        .ll_valid_in(),
                        .ll_byte_in(),
                        .ll_ready_out()
                    );


endmodule
`default_nettype wire
