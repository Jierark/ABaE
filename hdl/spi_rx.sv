`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module spi_rx
       #(  parameter DATA_WIDTH = 8
        )
        ( input wire clk_in,
          input wire rst_in,
          input wire data_in,
          input wire data_clk_in,
          input wire sel_in,
          output logic [DATA_WIDTH-1:0] data_out,
          output logic new_data_out
        );

    logic just_sent_data; 
    logic prev_data_clk_in; 
    logic [$clog2(DATA_WIDTH):0] bits_received;  
    logic [DATA_WIDTH-1:0] temp_data_out;

    initial begin
        data_out = 0; 
        new_data_out = 1'b0; 

        just_sent_data = 1'b1; 
        prev_data_clk_in = 1'b0;
        bits_received = 0; 
        temp_data_out = 0; 
    end

    always_ff @(posedge clk_in) begin 
        if (rst_in) begin
            data_out <= 0; 
            new_data_out <= 1'b0; 

            prev_data_clk_in <= 1'b0;

            just_sent_data <= 1'b0; 
            bits_received <= 0; 

            temp_data_out <= 0; 
        end else begin 
            prev_data_clk_in <= data_clk_in; 
            if (!sel_in && bits_received < DATA_WIDTH) begin 
                just_sent_data <= 1'b0;
                if (data_clk_in && !prev_data_clk_in) begin 
                    bits_received <= bits_received + 1; 
                    temp_data_out[DATA_WIDTH - 1 - bits_received] <= data_in; 
                end 
            end else if (bits_received == DATA_WIDTH) begin 
                if (!just_sent_data) begin
                    data_out <= temp_data_out; 
                    new_data_out <= 1'b1; 
                    just_sent_data <= 1'b1;
                end else begin 
                    new_data_out <= 1'b0; 
                    just_sent_data <= 1'b0; 
                    bits_received <= 0; 
                    temp_data_out <= 0; 
                end
            end else begin // sel_in is HIGH && bits_received < DATA_WIDTH (discard data)
                bits_received <= 0; 
                temp_data_out <= 1'b0; 
            end
        end
    end
endmodule
`default_nettype wire // prevents system from inferring an undeclared logic (good practice)
