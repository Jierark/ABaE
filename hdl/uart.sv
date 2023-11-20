module uart_rx(
    input wire clk_in, 
    input wire rst_in, 

    input wire uart_rxd_in, 
    output logic[7:0] byte_out,
    output logic valid_out,
);
    localparam CYCLES_PER_BAUD = 100_000_000 / 3_000_000;

    localparam WAITING = 0; 
    localparam BUILDING = 1;
    logic state;

    logic [$clog2(CYCLES_PER_BAUD)-1:0] baud_counter; 

    logic [3:0] bit_idx; 
    logic [1:0] bit_buffer;

    localparam RX_LENGTH = 8; 

    initial begin 
        state <= WAITING;
        bit_idx <= 0;
        bit_buffer <= 0; // For matching laptop's generated baud rate
    end
    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            state <= WAITING;
            bit_idx <= 0;
            bit_buffer <= 0;
        end else begin 
            if (state == WAITING) begin  // Waiting for initial low
                if (uart_rxd_in == 0) begin 
                    state <= GOT_ZERO;
                    baud_counter <= 1; 
                end 
            end else begin 
                baud_counter <= baud_counter + 1;
                if (baud_counter == CYCLES_PER_BAUD - 1) begin
                    bit_buffer <= {bit_buffer[0], uart_rxd_in};
                    bit_idx <= bit_idx + 1;
                    if (bit_idx == RX_LENGTH + 1) begin 
                        state <= WAITING;
                        valid_out <= 1;
                    end else begin
                        byte_out <= bit_buffer[1];
                    end
                end
            end 
        end
    end
endmodule


// Based on Manta's tx module
module uart_tx(
    input wire clk_in, 
    input wire rst_in, 
    input wire valid_in,
    input wire[7:0] byte_in,

    output logic uart_txd_out,
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
        uart_txd_out = 1;
        baud_counter = 0;
        bit_idx <= 0; 
    end 

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            state <= WAITING;
            buffer <= 0; 
            ready_out <= 1;
            uart_txd_out <= 1;
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
                    uart_txd_out <= 1'b0; // 0 bit
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
                    end else begin
                        uart_txd_out <= buffer[bit_idx];
                    end
                end
            end
        end
    end
endmodule

module manta_uart_tx (
	input wire clk_in,
    input wire rst_in,
	input wire [7:0] byte_in,
	input wire valid_in,
	output reg ready_out,

	output reg uart_txd_out);

	// this module supports only 8N1 serial at a configurable baudrate
	parameter CLOCKS_PER_BAUD = 100_000_000 / 3_000_000;
	reg [$clog2(CLOCKS_PER_BAUD)-1:0] baud_counter = 0;

	reg [8:0] buffer = 0;
	reg [3:0] bit_index = 0;

	initial ready_out = 1;
	initial uart_txd_out = 1;

	always @(posedge clk_in) begin
		if (valid_in && ready_out) begin
			baud_counter <= CLOCKS_PER_BAUD - 1;
			buffer <= {1'b1, byte_in};
			bit_index <= 0;
			ready_out <= 0;
			uart_txd_out <= 0;
		end

		else if (!ready_out) begin
			baud_counter <= baud_counter - 1;
			ready_out <= (baud_counter == 1) && (bit_index == 9);

			// a baud period has elapsed
			if (baud_counter == 0) begin
				baud_counter <= CLOCKS_PER_BAUD - 1;

				// clock out another bit if there are any left
				if (bit_index < 9) begin
					uart_txd_out <= buffer[bit_index];
					bit_index <= bit_index + 1;
				end

				// byte has been sent, send out next one or go to idle
				else begin
					if(valid_in) begin
						buffer <= {1'b1, byte_in};
						bit_index <= 0;
						uart_txd_out <= 0;
					end

					else ready_out <= 1;
				end
			end
		end
	end
endmodule