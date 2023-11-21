`timescale 1ns / 1ps
`default_nettype none

module uart_tx_tb();

    logic clk_in;
    logic rst_in;
    logic tx_valid_in;
    logic [7:0] byte_in;
    logic uart_txd;
    logic tx_ready_out;

    logic [9:0] bit_grabber;

    uart_tx transmitter(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .valid_in(tx_valid_in),
        .byte_in(byte_in),
        .uart_txd_out(uart_txd),
        .ready_out(tx_ready_out));

    logic passed = 1;

    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end
    //initial block...this is our test simulation
    initial begin
        $dumpfile("uart_tx_tb.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,uart_tx_tb);
        $display("Starting Sim"); //print nice message at start
        clk_in = 0;

        rst_in = 0; // Reset the system
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;

        for (int i = 0; i < 256; i = i + 1) begin 
            tx_valid_in = 1;
            byte_in = i; 
            bit_grabber = 0;
            #10;
            tx_valid_in = 0;
            for (int j = 0; j < 10; j=j+1) begin
                bit_grabber[j] = uart_txd;
                #330;
            end
            if (bit_grabber[8:1] != i[7:0]) begin
                passed = 0;
                $display("Failed, got %d expected %d.", bit_grabber[8:1], i[7:0]);
            end else begin
                // $display("Got %b %b %b, expected %8b", bit_grabber[9], bit_grabber[8:1], bit_grabber[0], i[7:0]);
            end
            #1000;
        end

        if (passed == 0) begin 
            $display("Tests failed.");
        end else begin
            $display("Tests passed!");
        end

        $display("Simulation Finished");
        $finish;
    end
endmodule
`default_nettype wire