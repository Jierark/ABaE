`timescale 1ns/1ps
`default_nettype none

module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw,      
    input wire [3:0] btn,
    input wire [7:0] pmoda,
    input wire uart_rxd,

    output logic [15:0] led    
    output logic [2:0] rgb0,   
    output logic [2:0] rgb1,   
    output logic [7:0] pmodb, 
    output logic uart_txd,
    );
    assign led = sw; 

    assign rgb0 = 0;  // Supress RGB LED's
    assign rgb1 = 0; 

    logic sys_rst;
    assign sys_rst = btn[0];
endmodule
`default_nettype wire ;