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
    input wire tx_valid_in,   // Downstream has sent new data

        // wires
    output logic tx_data_out,
    output logic tx_sel_out,
    output logic tx_clk_out,
    input wire tx_data_in,  // unused
    output logic tx_key_req_out,

    // rx parameters
    output logic [MESSAGE_SIZE-1:0] rx_message_out,
    output logic [HEADER_SIZE-1:0] rx_header_out,
    input wire rx_ready_in, // Downstream is ready to receive data
    output logic rx_valid_out, // New data available for downstream
        // wires
    input wire rx_data_in,
    input wire rx_sel_in,
    input wire rx_clk_in,
    output logic rx_data_send, // unused
    input wire rx_key_req_in
);
    localparam DATA_PERIOD = 100_000_000 / (UART_BAUD_RATE * 2); // Twice to avoid bottleneck here

    // for now no key negotiation, its just sent first thing and status LED set
    

    // logic tx_data_out; // throw away

    // logic tx_trigger_in;

    spi_tx #(
        .DATA_WIDTH(MESSAGE_SIZE + HEADER_SIZE),
        .DATA_PERIOD(DATA_PERIOD)
    ) tx (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in({tx_message_in, tx_header_in}),
        .trigger_in(tx_valid_in),
        .data_out(tx_data_out), // throw away
        .data_clk_out(tx_clk_out),
        .sel_out(tx_sel_out)
    );

    // logic rx_data_in;  // throw away

    logic [MESSAGE_SIZE+HEADER_SIZE-1:0] rx_combined_out;
    // logic rx_valid_out;

    spi_rx #(
        .DATA_WIDTH(MESSAGE_SIZE + HEADER_SIZE)
    ) rx (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(rx_data_in), 
        .data_clk_in(rx_clk_in),
        .sel_in(rx_sel_in),
        .data_out(rx_combined_out),
        .new_data_out(rx_valid_out),
        .ready_in(rx_ready_in)
    );
    // assign rx_header_out = 32'b001111111_00000000_00000000_0000_1_1_1;
    // assign rx_message_out = 128'h000102030405060708090a0b0c0d0e0f;

    assign rx_header_out = rx_combined_out[HEADER_SIZE-1:0];
    assign rx_message_out = rx_combined_out[MESSAGE_SIZE+HEADER_SIZE-1:HEADER_SIZE];
    always_comb begin 
        tx_ready_out = tx_sel_out; // If sel_out is high, ready to receive
                                   // Assumes connected module is ready
                                   // Might have to fudge this unfortunately

        // header_out[hdr_bit_idx+: BYTE_SIZE] <= ll_byte_in;
        // rx_header_out = rx_combined_out[HEADER_SIZE-1+:HEADER_SIZE];
        // rx_message_out = rx_combined_out[MESSAGE_SIZE+HEADER_SIZE-1+:MESSAGE_SIZE];
    end


endmodule
`default_nettype wire