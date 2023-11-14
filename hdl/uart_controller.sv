module uart_gateway #(parameter MESSAGE_SIZE = 512) (
    input clk_in,
    input rst_in, 


    // uart_tx params
    input wire new_transmission_in,    // HIGH when new full message to be made
    input wire [MESSAGE_SIZE-1:0] message_in,
    input wire [1:0] mode_in,          // 2'b00 = MIXED, 2'b01 = RAW, 2'b10 = ENC



    input uart_rx_in, 
    output uart_tx_out
);

endmodule
