`timescale 1ns / 1ps
`default_nettype none
module uart_rx_tb();

    logic clk_in;
    logic rst_in;
    logic [7:0] byte_out;
    logic uart_rx;
    logic valid_out;
    logic passed;

    logic [9:0] bit_grabber;

    uart_rx receiver(.clk_in(clk_in),
                     .rst_in(rst_in),
                     .uart_rx_in(uart_rx),
                     .byte_out(byte_out),
                     .valid_out(valid_out));

    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end
    //initial block...this is our test simulation
    initial begin
        $dumpfile("uart_rx_tb.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,uart_rx_tb);
        $display("Starting Sim"); //print nice message at start
        clk_in = 0;

        rst_in = 0; // Reset the system
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;
        uart_rx = 1;
        passed = 1;
        #500
        for (int i = 0; i < 256; i = i + 1) begin 
            uart_rx = 0;
            #330;
            for (int j = 0; j < 8; j=j+1) begin
                uart_rx = i[j];
                #330;
            end
            uart_rx = 1;
            #330
            
            if (i != byte_out) begin 
                passed = 0;
                $display("Failed, got %b, expected %8b", byte_out, i[7:0]);
            end else begin
                // $display("Got %b, expected %8b", byte_out, i[7:0]);
            end
            #1000;
        end

        if (passed == 0) begin 
            $display("\033[31m Tests failed.");
        end else begin
            $display("\033[32m Tests passed!");
        end        

        $display("\033[37m Simulation Finished");
        $finish;
    end
endmodule
`default_nettype wire