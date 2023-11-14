// We assume full duplex UART until this breaks

// This module is in charge of sending data to the FTDI USB Module via UART
// to be eventually sent to the laptop. 
module uart_tx_bridge #(parameter MESSAGE_SIZE = 512) (
    input wire clk_in,
    input wire rst_in,

    input wire new_transmission_in,    // HIGH when new full message to be made
    input wire [MESSAGE_SIZE-1:0] message_in,
    input wire [1:0] mode_in,          // 2'b00 = MIXED, 2'b01 = RAW, 2'b10 = ENC

    output logic uart_tx_out; 
    output logic busy_out;             // Signal to input modules that module is not ready to send (e.g. because other laptop isn't running)

); 
endmodule

module message_unpack #(parameter MESSAGE_SIZE = 512) (
    input wire clk_in, 
    input wire rst_in, 

    input [MESSAGE_SIZE-1:0] message_in, 
    output [7:0]
);
endmodule