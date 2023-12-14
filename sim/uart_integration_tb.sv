// Echoes a message between bridge rx and tx,
// building and deconstructing a 512-bit message
// from/to bytes
// This is basically the system skipping over the encryption/SPI
// elements

// Would be good to test this in hardware as well
// on a separate branch

`timescale 1ns/1ps
`default_nettype none

module uart_integration_tb();
    localparam UART_BAUD_RATE = 3_000_000;
    localparam MESSAGE_SIZE = 128;
    localparam HEADER_SIZE = 32;

    logic [MESSAGE_SIZE-1:0] message_received; 
    logic [HEADER_SIZE-1:0] header_received;

    logic [MESSAGE_SIZE-1:0] message_to_send_enc; 
    logic [MESSAGE_SIZE-1:0] message_to_send_dec; 
    logic [HEADER_SIZE-1:0] header_to_send;

    logic tx_valid_in;
    logic tx_ready_out;
    logic rx_valid_out;
    logic rx_ready_in;

    logic [15:0] led;
    logic clk_in;
    logic rst_in;
    logic [1:0] sw;

    logic uart_txd;
    logic uart_rxd;

    logic [7:0] START_BYTE;

    logic passed;

    logic [HEADER_SIZE-1:0] header;

    logic [MESSAGE_SIZE-1:0] message;
    

    uart_controller #(.MESSAGE_SIZE(MESSAGE_SIZE),
        .HEADER_SIZE(HEADER_SIZE),
        .BAUD_RATE(UART_BAUD_RATE)) uut (
        .clk_in(clk_in),
        .rst_in(rst_in),

        // Interface single-cycle signals
        .ext_tx_valid_in(tx_valid_in),  // Message done decrypting
        .ext_tx_ready_out(tx_ready_out), // Can receive new message
        .ext_rx_valid_out(rx_valid_out), // New message available to encrypt
        .ext_rx_ready_in(rx_ready_in),  // Encryption module ready

        // tx data inputs
        .tx_encrypted_in(message_to_send_enc),
        .tx_decrypted_in(message_to_send_dec),
        .tx_header_in(header_to_send),
        .tx_mode_in(sw[1:0]),

        // rx data outputs
        .rx_message_out(message_received),
        .rx_header_out(header_received),

        // uart signals
        .uart_rx_in(uart_rxd),
        .uart_tx_out(uart_txd),
        
        // temp debug
        .debug(led[15:2])
    );
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    initial begin
        $dumpfile("uart_integration_tb.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,uart_integration_tb);
        $display("Starting Sim"); //print nice message at start

        clk_in = 0;

        rst_in = 0; // Reset the system
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;

        passed = 1;

        rx_ready_in = 1; // always ready

        $display("Sending junk");
        // Send junk (0's)
        for (int i = 0; i < 100; i = i + 1) begin 
            uart_rxd = 0;
            #330;
            for (int j = 0; j < 8; j=j+1) begin
                uart_rxd = 0;
                #330;
            end
            uart_rxd = 1;
            #330;

            #1000;
        end

        // Send START_BYTE

        $display("Sending start");
        START_BYTE = 8'hbb;
        
        uart_rxd = 0;
        #330;
        
        for (int j = 0; j < 8; j=j+1) begin
            uart_rxd = START_BYTE[j];
            #330;
        end
        uart_rxd = 1;
        #330;

        #1000;
        
        header = 32'h01020304;
        message = 128'h0123456789abcdef_0123456789abcdef;
        // Send Header
        $display("Sending header");
        for (int i = 0; i < HEADER_SIZE; i = i + 8) begin 
            uart_rxd = 0;
            #330;
            for (int j = 0; j < 8; j=j+1) begin
                uart_rxd = header[i+j]; // send junk for now
                #330;
            end
            uart_rxd = 1;
            #330;

            #1000;
        end

        // Send Body
        $display("Sending body");
        for (int i = 0; i < MESSAGE_SIZE; i = i + 8) begin 
            uart_rxd = 0;
            #330;
            for (int j = 0; j < 8; j=j+1) begin
                uart_rxd = message[i+j]; // send junk for now
                #330;
            end
            uart_rxd = 1;
            #330;
            
            #1000;
        end
        
        $display("Done sending");
        // while (!rx_valid_out) begin 
        //     #10;
        //     $display("waiting");
        // end
        #10000;
        tx_valid_in = 1;
        header_to_send = header_received;
        message_to_send_enc = message_received;
        message_to_send_dec = message_received;

        
        #10000;
        while(!tx_ready_out) begin
            #10;
        end

        #10000;

        $display("Got header: %h", header_received);
        $display("Got message: %h", message_received);
        


        if (passed == 0) begin 
            $display("\033[31m Tests failed.");
        end else begin
            $display("\033[32m Tests passed!");
        end        

        $display("\033[37m Simulation Finished");
        $finish;
    end
endmodule
`default_nettype wire ;