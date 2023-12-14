`timescale 1ns / 1ps
`default_nettype none 

// This module is in charge of sending data to the FTDI USB Module via UART
// to be eventually sent to the laptop. 
module uart_tx_bridge #(parameter MESSAGE_SIZE = 512, parameter HEADER_SIZE=32) (
    input wire clk_in,
    input wire rst_in,

    // ctrl interface
    input wire [MESSAGE_SIZE-1:0] message_in,
    input wire [HEADER_SIZE-1:0] header_in,

    input wire ctrl_valid_in,      // HIGH when new full message to be made
    output logic bdge_ready_out,   // HIGH if upstream modules can send data in (e.g. because other laptop isn't running)

    // low level interface
    input wire ll_ready_in,         // HIGH if transmitter is ready to send new byte
    output logic [7:0] ll_byte_out, // byte to transmit
    output logic ll_valid_out,      // HIGH when new byte entered

    input wire sending_signal       // HIGH if sending special signal with no MESSAGE_SIZE-bit body. Needs to be held until done sending
); 

typedef enum {IDLE, SENDING_START, SENDING_HEADER, SENDING_MESSAGE} states;
states state;

logic [$clog2(HEADER_SIZE)-1:0] hdr_bit_idx;
logic [$clog2(MESSAGE_SIZE)-1:0] msg_bit_idx;

logic [MESSAGE_SIZE-1:0] message_buf; // store incoming message locally so upstream doesn't have to hold it
logic [HEADER_SIZE-1:0] header_buf;   // may blow up size though

localparam BYTE_SIZE = 8;

localparam LAST_HEADER_BYTE = HEADER_SIZE - BYTE_SIZE; // idx of start of last byte
localparam LAST_MESSAGE_BYTE = MESSAGE_SIZE - BYTE_SIZE;

localparam START_BYTE = 187; // 0xbb

initial begin 
    bdge_ready_out = 0;
    ll_byte_out = 0;
    ll_valid_out = 0;

    hdr_bit_idx = 0;
    msg_bit_idx = 0;
    state = IDLE;
end
always_ff @(posedge clk_in) begin 
    if (rst_in) begin 
        bdge_ready_out <= 0;
        ll_byte_out <= 0;
        ll_valid_out <= 0;
    
        hdr_bit_idx <= 0;
        msg_bit_idx <= 0;
        state <= IDLE;
    end else begin 
        if (state == IDLE) begin 
            if (ctrl_valid_in) begin 
                message_buf <= message_in; 
                header_buf <= header_in;
                state <= SENDING_START;
                bdge_ready_out <= 0;
                ll_valid_out <= 1;
            end else begin
                bdge_ready_out <= 1; 
                ll_valid_out <= 0;
            end
        end else if (state == SENDING_START) begin 
            if (ll_ready_in) begin 
                ll_byte_out <= START_BYTE;
                state <= SENDING_HEADER;
            end
        end else if (state == SENDING_HEADER) begin
            if (ll_ready_in) begin 
                ll_byte_out <= header_buf[hdr_bit_idx+:BYTE_SIZE];
                
                if (hdr_bit_idx == LAST_HEADER_BYTE) begin
                    hdr_bit_idx <= 0;
                    if (sending_signal) begin // Signals only send header
                        state <= IDLE;
                        bdge_ready_out <= 1;
                        ll_valid_out <= 0;
                    end else begin
                        state <= SENDING_MESSAGE;
                    end
                end else begin 
                    hdr_bit_idx <= hdr_bit_idx + BYTE_SIZE;
                end
            end
        end else if (state == SENDING_MESSAGE) begin
            if (ll_ready_in) begin
                ll_byte_out <= message_buf[msg_bit_idx+:BYTE_SIZE];
                
                if (msg_bit_idx == LAST_MESSAGE_BYTE) begin
                    state <= IDLE;
                    bdge_ready_out <= 1; 
                    msg_bit_idx <= 0;
                    ll_valid_out <= 0;
                end else begin 
                    msg_bit_idx <= msg_bit_idx + BYTE_SIZE;
                end
            end
        end
    end
end 

endmodule
`default_nettype wire