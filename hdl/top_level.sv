`timescale 1ns/1ps
`default_nettype none

// This will implement a simple circular UART channel such that messages are echoed back to the sender
// This is mostly for me to figure out how to make the core UART functionality work right for the real project
module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw,      
    input wire [3:0] btn,
    input wire [7:0] pmoda,
    input wire uart_rxd,

    output logic [15:0] led,    
    output logic [2:0] rgb0,   
    output logic [2:0] rgb1,   
    output logic [7:0] pmodb, 
    output logic uart_txd
    );
    // assign led = sw; 

    assign rgb0 = 0;  // Supress RGB LED's
    assign rgb1 = 0; 

    logic sys_rst;
    assign sys_rst = btn[0];


    logic [7:0] uart_byte; 
    logic uart_rx_valid_out;

    uart_rx #(.BAUD_RATE(12_000_000)) receiver(.clk_in(clk_100mhz),
                     .rst_in(sys_rst),
                     .uart_rx_in(uart_rxd),
                     .byte_out(uart_byte),
                     .valid_out(uart_rx_valid_out));

    always_ff @(posedge clk_100mhz) begin 
        if (uart_rx_valid_out) 
            led <= {8'b0, uart_byte};
    end


endmodule
`default_nettype wire ;