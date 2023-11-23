module uart_rx #(parameter BAUD_RATE = 3_000_000) (
    input wire clk_in, 
    input wire rst_in, 

    input wire uart_rx_in, 
    output logic[7:0] byte_out,
    output logic valid_out
);
    localparam CYCLES_PER_BAUD = 100_000_000 / BAUD_RATE;
    localparam HALF_BAUD = CYCLES_PER_BAUD / 2;

    localparam WAITING = 0; 
    localparam BUILDING = 1;
    localparam DONE = 2;
    localparam DELAY = 3;
    logic [1:0] state;

    logic [$clog2(CYCLES_PER_BAUD)-1:0] baud_counter; 

    logic [3:0] bit_idx; 
    logic [1:0] bit_buffer; // For matching laptop's generated baud rate

    localparam RX_LENGTH = 7; 

    initial begin 
        state <= WAITING;
        bit_idx <= 0;
        bit_buffer <= 0; 
        valid_out <= 0;
        byte_out <= 0;
    end
    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            state <= WAITING;
            bit_idx <= 0;
            bit_buffer <= 0;
            valid_out <= 0;
        end else begin 
            if (state == WAITING) begin  // Waiting for initial low
                valid_out <= 0;
                bit_idx <= 0;
                // bit_buffer <= 0;
                if (uart_rx_in == 0) begin 
                    state <= DELAY;
                    baud_counter <= 0; 
                end 
            end else if (state == DELAY) begin 
                if (baud_counter == HALF_BAUD - 1) begin 
                    baud_counter <= 0;
                    state <= BUILDING;
                end else begin 
                    baud_counter <= baud_counter + 1;
                end
            end else if (state == BUILDING) begin 
                if (baud_counter == CYCLES_PER_BAUD - 1) begin
                    baud_counter <= 0;
                    // bit_buffer <= {bit_buffer[0], uart_rx_in};
                    bit_idx <= bit_idx + 1;
                    byte_out[bit_idx] <= uart_rx_in;
                    // byte_out[bit_idx - 1] <= bit_buffer[1];
                    if (bit_idx == RX_LENGTH) begin 
                        state <= DONE;
                    end 
                end else begin 
                    baud_counter <= baud_counter + 1;
                end
            end else begin
                if (baud_counter == CYCLES_PER_BAUD - 1) begin
                    baud_counter <= 0;
                    state <= WAITING;
                    if (uart_rx_in == 1) begin // Got stop bit
                        valid_out <= 1;
                    end 
                end else begin 
                    baud_counter <= baud_counter + 1;
                end
            end
        end
    end
endmodule


// Based on Manta's tx module
module uart_tx #(parameter BAUD_RATE = 3_000_000) (
    input wire clk_in, 
    input wire rst_in, 
    input wire valid_in,
    input wire[7:0] byte_in,

    output logic uart_tx_out,
    output logic ready_out
    );

    logic [3:0] bit_idx; 
    logic [8:0] buffer; 

    localparam CYCLES_PER_BAUD = 100_000_000 / 3_000_000;
    localparam TX_LENGTH = 8; 

    localparam WAITING = 0; 
    localparam SENDING = 1; 

    logic state;

    logic [$clog2(CYCLES_PER_BAUD)-1:0] baud_counter; 

    initial begin 
        state = WAITING;
        buffer = 0; 
        ready_out = 1;
        uart_tx_out = 1;
        baud_counter = 0;
        bit_idx <= 0; 
    end 

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            state <= WAITING;
            buffer <= 0; 
            ready_out <= 1;
            uart_tx_out <= 1;
            baud_counter <= 0;
            bit_idx <= 0; 
        end else begin 
            if (state == WAITING) begin 
                if (valid_in) begin
                    state <= SENDING;
                    buffer <= {1'b1, byte_in};
                    ready_out <= 0;
                    baud_counter <= 0;
                    bit_idx <= 0; 
                    uart_tx_out <= 1'b0; // 0 bit
                end else begin 
                    ready_out <= 1;
                end
            end else begin 
                baud_counter <= (baud_counter == CYCLES_PER_BAUD-1) ? 0 : baud_counter + 1; 
                if (baud_counter == CYCLES_PER_BAUD-1) begin 
                    bit_idx <= bit_idx + 1; 
                    if (bit_idx == TX_LENGTH + 1) begin 
                        state <= WAITING;
                        ready_out <= 1;
                        // Add direct transfer to next here
                    end else begin
                        uart_tx_out <= buffer[bit_idx];
                    end
                end
            end
        end
    end
endmodule