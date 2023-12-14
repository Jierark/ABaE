`timescale 1ns / 1ps
`default_nettype none
module uart_tx_bridge_tb();
    localparam MESSAGE_SIZE = 512;
    localparam HEADER_SIZE = 32;

    logic clk_in;
    logic rst_in;
    logic [MESSAGE_SIZE-1:0] message_in;
    logic [HEADER_SIZE-1:0] header_in;
    logic ctrl_valid_in;
    logic bdge_ready_out;
    logic ll_ready_in;
    logic [7:0] ll_byte_out;
    logic ll_valid_out;

    logic passed;
    logic [MESSAGE_SIZE-1:0] message;
    logic [HEADER_SIZE-1:0] header;

    uart_tx_bridge #(.MESSAGE_SIZE(MESSAGE_SIZE),
        .HEADER_SIZE(HEADER_SIZE)) tx_bridge(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .message_in(message_in),
        .header_in(header_in),
        .ctrl_valid_in(ctrl_valid_in),
        .bdge_ready_out(bdge_ready_out),
        .ll_ready_in(ll_ready_in),
        .ll_byte_out(ll_byte_out),
        .ll_valid_out(ll_valid_out),
        .sending_signal(0)
   );

    logic [MESSAGE_SIZE-1:0] message_sent;
    logic [HEADER_SIZE-1:0] header_sent;
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end
    //initial block...this is our test simulation
    initial begin
        $dumpfile("uart_tx_bridge_tb.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,uart_tx_bridge_tb);
        $display("Starting Sim"); //print nice message at start
        clk_in = 0;

        rst_in = 0; // Reset the system
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;

        passed = 1;

        message_sent = 0;
        header_sent = 0;

        // 32 bit header, 512 bit message
        header_in = 32'hFAFA_FAFA;
        message_in = 512'h0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef;
        #10;
        ctrl_valid_in = 1; 
        
        while (!bdge_ready_out) begin 
            #10; // wait until bridge is ready
        end
        #100; // test buffer
        for (int i = 0; i < 32; i = i + 8) begin
            ll_ready_in = 1; 
            #10; // give it a second to register ready_in
            while (!ll_valid_out) begin 
                #10; // wait until valid byte sent out <-- weirdness HERE
            end
            ll_ready_in = 0; // prevent fall-through
            header_sent[i+:8] = ll_byte_out;
            // $display("Got byte: %h", ll_byte_out);
            #80; // wait some time while uart is "sent"
        end
        
        for (int i = 0; i < 512; i = i + 8) begin
            ll_ready_in = 1; 
            #10; // give it a second to register ready_in
            while (!ll_valid_out) begin 
                #10; // wait until valid byte sent out <-- weirdness HERE
            end
            ll_ready_in = 0; // prevent fall-through
            message_sent[i+:8] = ll_byte_out;
            #80; // wait some time while uart is "sent"
        end
        
        #200; // wait a bit until "downstream" ready

        if (header_in != header_sent) begin 
            $display("Failed header, received  %h\n, expected %h", header_sent, header_in);
            passed = 0;
        end
        if (message_in != message_sent) begin 
            $display("Failed message, received  %h\n, expected %h", message_sent, message_in);
            passed = 0;
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