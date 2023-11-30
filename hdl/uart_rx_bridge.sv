`timescale 1ns / 1ps
`default_nettype none 
// This module is in charge of receiving data from FTDI USB Module via UART
module uart_rx_bridge #(parameter MESSAGE_SIZE = 512, parameter HEADER_SIZE=32) (
    input wire clk_in,
    input wire rst_in,

    // ctrl interface
    output logic [MESSAGE_SIZE-1:0] message_out, 
    output logic [HEADER_SIZE-1:0] header_out,

    input wire ctrl_ready_in,
    output logic bdge_valid_out,

    // ll interface
    input wire ll_valid_in,
    input wire [7:0] ll_byte_in,
    output wire ll_ready_out
); 
endmodule

// module message_pack #(parameter MESSAGE_SIZE = 512) (
//     input wire clk_in, 
//     input wire rst_in, 

//     input [MESSAGE_SIZE-1:0] message_in, 
//     output [7:0]
// );
// endmodule
`default_nettype none 