`timescale 1ns / 1ps
`default_nettype none 
module uart_controller #(parameter MESSAGE_SIZE = 512, 
                         parameter HEADER_SIZE = 32,
                         parameter BAUD_RATE = 12_000_000) (
    input wire clk_in,
    input wire rst_in, 


    // uart_tx params
    input wire ext_tx_valid_in,    // HIGH when new full message entered
    output logic ext_tx_ready_out, // HIGH when ready to receive new message
    input wire [MESSAGE_SIZE-1:0] tx_encrypted_in,
    input wire [MESSAGE_SIZE-1:0] tx_decrypted_in,
    input wire [HEADER_SIZE-1:0] tx_header_in,
    input wire [1:0] tx_mode_in,          // 2'b11 = MIXED, 2'b01 = ENC, 2'b00 = DEC, 2'b10 = ENC
    

    // uart_rx params
    output logic ext_rx_valid_out, // HIGH when new full message out
    input wire ext_rx_ready_in,   // HIGH when downstream module can receive new message
    output logic [MESSAGE_SIZE-1:0] rx_message_out,
    output logic [HEADER_SIZE-1:0] rx_header_out,

    // uart signals
    input wire uart_rx_in, 
    output logic uart_tx_out,

    output logic [13:0] debug,
    input wire debug_btn
);
    localparam MIXED = 3;
    localparam ENC = 1;
    localparam OTHER_ENC = 2;
    localparam DEC = 0;

    // controller to tx bridge
    logic [MESSAGE_SIZE-1:0] tx_bdge_message_in;
    logic [HEADER_SIZE-1:0] tx_bdge_header_in;
    logic tx_ctrl_valid_in;
    logic tx_bdge_ready_out;
    logic tx_bdge_sending_signal;

    // tx bridge to tx low level
    logic tx_bdge_valid_out;
    logic [7:0] tx_bdge_byte_out;
    logic tx_ll_ready_out;
    logic tx_is_encrypted;

    uart_tx_bridge #(.MESSAGE_SIZE(MESSAGE_SIZE),
                     .HEADER_SIZE(HEADER_SIZE)) tx_bridge(
                        .clk_in(clk_in),
                        .rst_in(rst_in),
                        .message_in(tx_bdge_message_in),
                        .header_in(tx_bdge_header_in),
                        .ctrl_valid_in(tx_ctrl_valid_in),
                        .bdge_ready_out(tx_bdge_ready_out),
                        .ll_ready_in(tx_ll_ready_out),
                        .ll_byte_out(tx_bdge_byte_out),
                        .ll_valid_out(tx_bdge_valid_out),
                        .sending_signal(tx_bdge_sending_signal)
                    );

    uart_tx #(.BAUD_RATE(BAUD_RATE)) tx (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .valid_in(tx_bdge_valid_out),
        .byte_in(tx_bdge_byte_out),
        .uart_tx_out(uart_tx_out),
        .ready_out(tx_ll_ready_out)
    );

    // rx bridge to controller
    logic [MESSAGE_SIZE-1:0] rx_message_buffer; // consider deleting these
    logic [HEADER_SIZE-1:0] rx_header_buffer;  // or replacing them with BRAM

    logic rx_ctrl_ready_in;  // controller is ready to receive new data
    logic rx_bdge_valid_out; // new message out from bridge

    // rx bridge to rx low level
    logic rx_bgde_ready_out;    // bridge ready to receive a byte
    logic [7:0] rx_ll_byte_out; // byte from low level
    logic rx_ll_valid_out;      // new byte from ll

    uart_rx_bridge #(.MESSAGE_SIZE(MESSAGE_SIZE),
                     .HEADER_SIZE(HEADER_SIZE)) rx_bridge(
                        .clk_in(clk_in),
                        .rst_in(rst_in),
                        .message_out(rx_message_buffer),
                        .header_out(rx_header_buffer),
                        .ctrl_ready_in(rx_ctrl_ready_in),
                        .bdge_valid_out(rx_bdge_valid_out),
                        .ll_valid_in(rx_ll_valid_out),
                        .ll_byte_in(rx_ll_byte_out),
                        .ll_ready_out(rx_bgde_ready_out),
                        .debug(debug[5:2]),
                        .debug_btn(debug_btn)
                    );
    uart_rx #(.BAUD_RATE(BAUD_RATE)) rx (
                .clk_in(clk_in),
                .rst_in(rst_in),
                .uart_rx_in(uart_rx_in),
                .byte_out(rx_ll_byte_out),
                .ready_in(rx_bgde_ready_out),
                .valid_out(rx_ll_valid_out),
                .debug(debug[13:6])
            );

    
    // RX Pipeline
    typedef enum {RX_IDLE, RX_STALLED} rx_states;
    rx_states rx_state;
    initial begin 
        rx_state = RX_IDLE;
        ext_rx_valid_out = 0;
        rx_ctrl_ready_in = 1;
    end
    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            rx_state <= RX_IDLE;
            ext_rx_valid_out <= 0;
            rx_ctrl_ready_in <= 1;
        end else begin 
            case (rx_state)
                RX_IDLE: begin 
                    rx_ctrl_ready_in <= 1; // make sure this is set in all cases
                    if (rx_bdge_valid_out) begin 
                        ext_rx_valid_out <= 1;   // signal out that we have received message
                        rx_message_out <= rx_message_buffer; // clear buffers
                        rx_header_out <= rx_header_buffer;

                        if (!ext_rx_ready_in) begin
                            rx_state <= RX_STALLED;
                            rx_ctrl_ready_in <= 0;
                        end

                        debug[0] <= 0; // debug
                    end else begin // we are waiting for data to come in
                        ext_rx_valid_out <= 0;

                        // debug[0] <= 1; // debug
                    end
                end
                RX_STALLED: begin
                    if (ext_rx_ready_in) begin // wait until external is ready
                        rx_state <= RX_IDLE;
                        rx_ctrl_ready_in <= 1;

                        debug[1] <= 0; // debug
                    end else begin 
                        // debug[0] <= 1; // debug
                    end
                end
            endcase
        end
    end

    // TX Pipeline
    // << needs to send message when RX is full and when it becomes ready again, wait until TX is done
    localparam STALL_SIGNAL = 32'b000000000_00000000_10000000_0000_0_0_0; // if using different header size needs to be adjusted
    localparam UNSTALL_SIGNAL = 32'b000000000_00000000_01000000_0000_0_0_0;
    typedef enum {TX_IDLE, TX_STALLED, TX_SENDING_STALL, TX_SENDING_UNSTALL, TX_DONE_SENDING} tx_states;
    tx_states tx_state;
    logic sent_stall_signal;
    logic tx_mux; // alternate encrypted and decrypted if in BOTH mode
    logic signal_stall_en;
    logic signal_unstall_en;
    logic signal_to_send;

    // Set RAW_FLAG
    logic [HEADER_SIZE-1:0] flipped_header;
    logic is_raw;
    assign is_raw = tx_mux || (tx_mode_in[0] ^ tx_mode_in[1]);
    assign flipped_header = {tx_header_in[HEADER_SIZE-1:3], is_raw, tx_header_in[1:0]};

    initial begin
        tx_state = TX_IDLE;
        sent_stall_signal = 0;
        tx_mux = 0;
        tx_ctrl_valid_in = 0;
        ext_tx_ready_out = 0;
    end
    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            tx_state <= TX_IDLE;
            sent_stall_signal <= 0;
            tx_mux <= 0;
            tx_ctrl_valid_in <= 0;
            ext_tx_ready_out <= 0;
        end else begin 
            if (tx_mode_in != MIXED) begin
                tx_mux <= 0; // reset encryption/decryption send order
            end

            case (tx_state)
                TX_IDLE: begin 
                    if (signal_stall_en) begin  //  need to check this when exiting message too 
                        tx_state <= TX_SENDING_STALL;
                        ext_tx_ready_out <= 0;
                        tx_bdge_header_in <= STALL_SIGNAL;
                        tx_ctrl_valid_in <= 1;
                        tx_bdge_sending_signal <= 1;

                    end else if (signal_unstall_en) begin 
                        tx_state <= TX_SENDING_UNSTALL;
                        ext_tx_ready_out <= 0;
                        tx_bdge_header_in <= UNSTALL_SIGNAL;
                        tx_ctrl_valid_in <= 1;
                        tx_bdge_sending_signal <= 1;

                    end else if (ext_tx_valid_in || (tx_mux && tx_mode_in == MIXED)) begin
                        tx_ctrl_valid_in <= 1;
                        tx_bdge_header_in <= flipped_header;  // need to flip bit // TODO <- this
                        if (tx_bdge_ready_out) begin 
                            // Handle sending both encrypted and decrypted versions
                            tx_state <= TX_DONE_SENDING;
                            ext_tx_ready_out <= 0;
                        end else begin
                            tx_state <= TX_STALLED;
                            ext_tx_ready_out <= 0;
                        end
                    end else begin
                        ext_tx_ready_out <= 1;
                        tx_ctrl_valid_in <= 0;
                    end
                end
                TX_STALLED: begin 
                    if (tx_bdge_ready_out) begin 
                        tx_state <= TX_DONE_SENDING;
                        tx_ctrl_valid_in <= 0;
                    end
                end
                TX_SENDING_STALL: begin 
                    tx_bdge_sending_signal <= 0;
                    if (tx_bdge_ready_out) begin 
                        tx_state <= TX_IDLE;
                        tx_ctrl_valid_in <= 0;
                        sent_stall_signal <= 1;
                    end
                end
                TX_SENDING_UNSTALL: begin 
                    tx_bdge_sending_signal <= 0;
                    if (tx_bdge_ready_out) begin 
                        tx_state <= TX_IDLE;
                        tx_ctrl_valid_in <= 0;
                        sent_stall_signal <= 0;
                    end
                end
                TX_DONE_SENDING: begin
                    // Handle sending both encrypted and decrypted versions
                    tx_ctrl_valid_in <= 0;
                    if (tx_mode_in == MIXED) begin
                        tx_mux <= !tx_mux;
                        if (tx_mux) begin // TODO <- this
                            ext_tx_ready_out <= !signal_to_send; // if there's a signal to send, don't signal ready yet
                        end else begin
                            ext_tx_ready_out <= 0;
                        end
                    end else begin 
                        ext_tx_ready_out <= !signal_to_send; // if there's a signal to send, don't signal ready yet
                    end
                    tx_state <= TX_IDLE;
                end
            endcase
        end
    end

    // todo - header bit flipping when mux is 0 or mode is ENC
    //      - tx mux readyness, needs to be ready once mux goes back to 0 not at 1
    // tx speed stuff is on python's side, don't write and you will get full read speed (maybe idk)

    // message multiplexer

    always_comb begin 
        case (tx_mode_in) 
            MIXED : tx_bdge_message_in = (tx_mux) ? tx_encrypted_in : tx_decrypted_in; // alternate, decrypted first
            ENC : tx_bdge_message_in = tx_encrypted_in;
            DEC : tx_bdge_message_in = tx_decrypted_in;
            default: tx_bdge_message_in = tx_encrypted_in;
        endcase
    end

    assign signal_stall_en = (rx_state == RX_STALLED && !sent_stall_signal);
    assign signal_unstall_en = (rx_state != RX_STALLED && sent_stall_signal);
    assign signal_to_send = (signal_stall_en || signal_unstall_en);

endmodule
`default_nettype wire
