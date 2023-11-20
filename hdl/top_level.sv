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
    // logic [7:0] uart_byte_rx; 

    // uart_rx receiver(.clk_in(clk_100mhz),
    //                  .rst_in(sys_rst),
    //                  .uart_rxd_in(uart_rxd),
    //                  .byte_out(uart_byte_rx));

    // assign led[7:0] = uart_byte_rx; 

    logic counter; 
    logic tx_ready_out; 
    logic tx_valid_in;

    // assign tx_valid_in = 1;
    logic state;
    initial state = 1;
    initial counter = 1;
    always_ff @(posedge clk_100mhz) begin 
        if (state == 0) begin 
            if (counter == 0 && tx_ready_out) begin
                state <= 1;
                counter <= 1;
                tx_valid_in <= 1;
            end else begin 
                counter <= counter + 1;
            end
        end else begin 
            if (tx_ready_out && tx_valid_in == 0) begin
                state <= 0;
                uart_byte <= uart_byte + 1;
            end else begin 
                tx_valid_in <= 0;
            end
        end
        

        // if (tx_ready_out) begin 
        //     counter <= counter + 1; 
        //     if (counter == 0) begin 
        //         uart_byte <= uart_byte + 1;
        //     end else begin
        //         tx_valid_in <= 0;
        //     end
        //     // tx_valid_in <= 1;
        // end else begin
        //     // tx_valid_in <= 0;
        // end
    end

    assign led = {8'b0, uart_byte};

    uart_tx transmitter(.clk_in(clk_100mhz),
                        .rst_in(sys_rst),
                        .valid_in(tx_valid_in),
                        .byte_in(uart_byte),
                        .uart_txd_out(uart_txd),
                        .ready_out(tx_ready_out));

endmodule
`default_nettype wire ;