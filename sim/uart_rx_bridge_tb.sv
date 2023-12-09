`timescale 1ns / 1ps
`default_nettype none
module uart_rx_bridge_tb();
    localparam MESSAGE_SIZE = 512;
    localparam HEADER_SIZE = 32;

    logic clk_in;
    logic rst_in;
    logic [MESSAGE_SIZE-1:0] message_out;
    logic [HEADER_SIZE-1:0] header_out;
    logic ctrl_ready_in;
    logic bdge_valid_out;
    logic ll_valid_in;
    logic [7:0] ll_byte_in;
    logic ll_ready_out;

    logic passed;
    logic [MESSAGE_SIZE-1:0] message;
    logic [HEADER_SIZE-1:0] header;

    uart_rx_bridge #(.MESSAGE_SIZE(MESSAGE_SIZE),
        .HEADER_SIZE(HEADER_SIZE)) uut(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .message_out(message_out),
        .header_out(header_out),
        .ctrl_ready_in(ctrl_ready_in),
        .bdge_valid_out(bdge_valid_out),
        .ll_valid_in(ll_valid_in),
        .ll_byte_in(ll_byte_in),
        .ll_ready_out(ll_ready_out)
    );
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end
    //initial block...this is our test simulation
    initial begin
        $dumpfile("uart_rx_bridge_tb.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,uart_rx_bridge_tb);
        $display("Starting Sim"); //print nice message at start
        clk_in = 0;

        rst_in = 0; // Reset the system
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;

        passed = 1;

        ctrl_ready_in = 0;

        $display("Waiting for module to be ready.");
        while (!ll_ready_out) begin
            #10; // wait until ready to process
        end
        // 32 bit header, 512 bit message
        header = 32'hFAFA_FAFA;
        for (int i = 0; i < 32; i = i + 8) begin 
            ll_byte_in = header[i+:8];
            ll_valid_in = 1;
            #10;
            ll_valid_in = 0;
            #80; // Real baudrate is slower than this
        end
        message = 512'h0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef_0123456789abcdef;
        for (int i = 0; i < 512; i = i + 8) begin 
            ll_byte_in = message[i+:8];
            ll_valid_in = 1;
            #10;
            ll_valid_in = 0;
            #80; // Real baudrate is slower than this
        end
        
        #200; // wait a bit until "downstream" ready
        ctrl_ready_in = 1;
        while (!bdge_valid_out) begin 
            #10; // wait until valid received
        end
        #50;
        ctrl_ready_in = 0; // controller no longer ready

        if (header_out != header) begin 
            $display("Failed header, received  %h\n, expected %h", header_out, header);
            passed = 0;
        end
        if (message_out != message) begin 
            $display("Failed message, received  %h\n, expected %h", message_out, message);
            passed = 0;
        end
        if (passed) begin 
            $display("First Message passed!");
        end
        // --------------------------------------------
        // Sending second message
        // --------------------------------------------
        $display("Waiting for module to be ready.");
        while (!ll_ready_out) begin
            #10; // wait until ready to process
        end
        // 32 bit header, 512 bit message
        header = 32'hBCBC_BCBC;
        for (int i = 0; i < 32; i = i + 8) begin 
            ll_byte_in = header[i+:8];
            ll_valid_in = 1;
            #10;
            ll_valid_in = 0;
            #80; // Real baudrate is slower than this
        end
        message = 512'hfedcba9876543210_fedcba9876543210_fedcba9876543210_fedcba9876543210_fedcba9876543210_fedcba9876543210_fedcba9876543210_fedcba9876543210;
        for (int i = 0; i < 512; i = i + 8) begin 
            ll_byte_in = message[i+:8];
            ll_valid_in = 1;
            #10;
            ll_valid_in = 0;
            #80; // Real baudrate is slower than this
        end
        
        #200; // wait a bit until "downstream" ready
        ctrl_ready_in = 1;
        while (!bdge_valid_out) begin 
            #10; // wait until valid received
        end
        #50;
        ctrl_ready_in = 0; // controller no longer ready

        if (header_out != header) begin 
            $display("Failed header, received  %h\n, expected %h", header_out, header);
            passed = 0;
        end
        if (message_out != message) begin 
            $display("Failed message, received  %h\n, expected %h", message_out, message);
            passed = 0;
        end

        if (passed == 1) begin
            $display("Second Message passed!");
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