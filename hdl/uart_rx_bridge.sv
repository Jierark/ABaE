`timescale 1ns / 1ps
`default_nettype none 
// This module is in charge of receiving data from FTDI USB Module via UART
module uart_rx_bridge #(parameter MESSAGE_SIZE = 512, parameter HEADER_SIZE=32) (
    input wire clk_in,
    input wire rst_in,

    // ctrl interface
    output logic [MESSAGE_SIZE-1:0] message_out, 
    output logic [HEADER_SIZE-1:0] header_out,

    input wire ctrl_ready_in,      // downstream ready to receive data (encryption module, spi etc.)
    output logic bdge_valid_out,   // single-cycle message is done

    // ll interface
    input wire ll_valid_in,        // got new byte from rx module
    input wire [7:0] ll_byte_in,   // byte from rx module
    output logic ll_ready_out,       // let rx module know that this module/downstream is ready for more data

    output logic [3:0] debug,
    input wire debug_btn
); 
    typedef enum {IDLE, BUILDING_HEADER, BUILDING_MESSAGE, DONE} states; // header arrives first
    states state;
    
    logic [$clog2(HEADER_SIZE)-1:0] hdr_bit_idx;
    logic [$clog2(MESSAGE_SIZE)-1:0] msg_bit_idx;

    localparam BYTE_SIZE = 8;

    localparam LAST_HEADER_BYTE = HEADER_SIZE - BYTE_SIZE; // idx of start of last byte
    localparam LAST_MESSAGE_BYTE = MESSAGE_SIZE - BYTE_SIZE;

    // localparam START_BYTE = 187; // 0xbb

    logic [7:0] START_BYTE;
    // AXI things:
    //   module's downstream valid_out must not depend on downstream's ready_in

    initial begin 
        state = IDLE;
        hdr_bit_idx = 0;
        msg_bit_idx = 0;

        header_out = 0; // consider leaving undefined
        message_out = 0;

        bdge_valid_out = 0;
        ll_ready_out = 0;

        START_BYTE = 8'hbb; // testing this

        debug = 0; // debug
    end


    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            state <= IDLE;
            hdr_bit_idx <= 0;
            msg_bit_idx <= 0;

            header_out <= 0; // consider leaving undefined
            message_out <= 0;

            bdge_valid_out <= 0;
            ll_ready_out <= 0;

            debug <= 0;  // debug
        end else begin 
            if (debug_btn) begin 
                debug[3] <= 0;
            end
            if (state == IDLE) begin
                ll_ready_out <= 1; // should be HIGH for entire transmission
                bdge_valid_out <= 0; 
                if (ll_valid_in) begin
                    // if (ll_byte_in == 8'hbb) begin // Wait until you get START_BYTE
                    //     state <= BUILDING_HEADER;
                        
                    //     debug[3] <= 1; // got a start byte
                    // end

                    state <= BUILDING_HEADER;
                    
                    // end else begin 
                    //     // debug[3] <= 0;
                    // end
                    debug[0] <= 0; // debug
                    
                end else begin // debug
                    debug[0] <= 1; // debug
                    // debug[3] <= 0;
                end
            end else if (state == BUILDING_HEADER) begin 
                if (ll_valid_in) begin 
                    // header_out[hdr_bit_idx+: BYTE_SIZE] <= ll_byte_in;
                    header_out[hdr_bit_idx+: BYTE_SIZE] <= ll_byte_in;
                    
                    if (hdr_bit_idx == LAST_HEADER_BYTE) begin 
                        state <= BUILDING_MESSAGE;
                        hdr_bit_idx <= 0; 

                        // debug[1] <= 0; // debug
                    end else begin 
                        hdr_bit_idx <= hdr_bit_idx + BYTE_SIZE;
                        
                    end
                end else begin
                    // debug[1] <= 1; // debug
                end
            end else if (state == BUILDING_MESSAGE) begin 
                if (ll_valid_in) begin 
                    message_out[msg_bit_idx+: BYTE_SIZE] <= ll_byte_in;
                    
                    if (msg_bit_idx == LAST_MESSAGE_BYTE) begin 
                        state <= DONE;
                        bdge_valid_out <= 1;
                        msg_bit_idx <= 0;

                        debug[2] <= 0; // debug
                    end else begin 
                        msg_bit_idx <= msg_bit_idx + BYTE_SIZE;
                    end 
                end else begin
                    debug[2] <= 1; // debug
                end             
            end else if (state == DONE) begin // stay here until downstream ready to receive
                ll_ready_out <= 0;
                bdge_valid_out <= 1;
                if (ctrl_ready_in) begin // downstream MUST consume outgoing data immediately, otherwise may get overwritten
                    state <= IDLE;
                    // ll_ready_out <= 1;
                    // bdge_valid_out <= 0;

                    debug[1] <= 0; // debug
                end else begin 
                    // ll_ready_out <= 0; // stall pipeline until downstream ready
                    // bdge_valid_out <= 1;     // valid_out must not depend on ready_in
                    debug[1] <= 1;
                end
            end
        end
    end

endmodule

// module message_pack #(parameter MESSAGE_SIZE = 512) (
//     input wire clk_in, 
//     input wire rst_in, 

//     input [MESSAGE_SIZE-1:0] message_in, 
//     output [7:0]
// );
// endmodule
`default_nettype none 