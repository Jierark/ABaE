`timescale 1ns / 1ps
`default_nettype none 

// This module is in charge of sending data to the FTDI USB Module via UART
// to be eventually sent to the laptop. 
module uart_tx_bridge #(parameter MESSAGE_SIZE = 512, parameter HEADER_SIZE=32) (
    input wire clk_in,
    input wire rst_in,

    // ctrl interface
    input wire [MESSAGE_SIZE-1:0] message_in,
    input wire [HEADER_SIZE-1:0] header_in,

    input wire ctrl_valid_in,      // HIGH when new full message to be made
    output logic bdge_ready_out,   // Signal to input modules that module is ready to send (e.g. because other laptop isn't running)

    // low level interface
    input wire ll_ready_in,
    output logic [7:0] ll_byte_out,
    output logic ll_valid_out
); 

endmodule

// module message_unpack #(parameter MESSAGE_SIZE = 512) (
//     input wire clk_in, 
//     input wire rst_in, 

//     input [MESSAGE_SIZE-1:0] message_in, 
//     output [7:0]
// );
// endmodule
`default_nettype wire