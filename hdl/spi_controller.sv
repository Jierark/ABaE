`timescale 1ns / 1ps
`default_nettype none 

module spi_controller #(parameter UART_BAUD_RATE = 12_000_000,
                        parameter MESSAGE_SIZE = 512,
                        parameter HEADER_SIZE = 32) (
    input wire clk_in,
    input wire rst_in,

    // tx parameters
    input wire [MESSAGE_SIZE-1:0] tx_message_in, 
    input wire [HEADER_SIZE-1:0] tx_header_in,
    output logic tx_ready_out, // Ready to transmit (from handshake)
    input logic tx_valid_in,   // Downstream has sent new data

        // wires
    output logic tx_data_out,
    output logic tx_sel_out,
    output logic tx_clk_out,
    input wire tx_data_in,
    output logic tx_key_req_out,

    // rx parameters
    output logic [MESSAGE_SIZE-1:0] rx_message_out,
    output logic [HEADER_SIZE-1:0] rx_header_out,
    input logic rx_ready_in, // Downstream is ready to receive data
    output logic rx_valid_out, // New data available for downstream
        // wires
    input wire rx_data_in,
    input wire rx_sel_in,
    input wire rx_clk_in,
    input wire rx_key_req_in
);
    localparam DATA_PERIOD = 100_000_000 / (UART_BAUD_RATE * 2); // Twice to avoid bottleneck here

    spi_tx #(
        .DATA_WIDTH(MESSAGE_SIZE + HEADER_SIZE),
        .DATA_PERIOD(DATA_PERIOD)
    ) tx (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(),
        .trigger_in(),
        .data_out(),
        .data_clk_out(tx_clk_out),
        .sel_out()
    );

    spi_rx #(
        .DATA_WIDTH(MESSAGE_SIZE + HEADER_SIZE)
    ) rx (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(),
        .data_clk_in(rx_clk_in),
        .data_out(),
        .new_data_out()
    );


endmodule
`default_nettype wire