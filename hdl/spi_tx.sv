`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
//don't worry about weird edge cases
//we want a clean 50% duty cycle clock signal
module spi_tx
       #(   parameter DATA_WIDTH = 8,
            parameter DATA_PERIOD = 100
        )
        ( input wire clk_in,
          input wire rst_in,
          input wire [DATA_WIDTH-1:0] data_in,
          input wire trigger_in,
          output logic data_out,
          output logic data_clk_out,
          output logic sel_out
        );
    
    logic [$clog2(DATA_WIDTH):0] bits_sent; 
    logic [$clog2(DATA_PERIOD)+1:0] clk_out_count;
    integer DATA_HALF_PERIOD; 
    logic [DATA_WIDTH-1:0] stored_data_in; 

    initial begin
        DATA_HALF_PERIOD = DATA_PERIOD/2;
        data_out = 1'b0; 
        data_clk_out = 1'b0; 
        sel_out = 1'b1; 

        bits_sent = 0; 
        clk_out_count = 0; 
    end

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            data_out <= 1'b0; 
            data_clk_out <= 1'b0; 
            sel_out <= 1'b1; 

            bits_sent <= 0; 
            clk_out_count <= 0;
            stored_data_in <= 0; 

        end else begin
            if (trigger_in && sel_out) begin
                data_out <= data_in[DATA_WIDTH - 1];
                data_clk_out <= 1'b0; 
                sel_out <= 1'b0; 

                bits_sent <= 1; 
                clk_out_count <= 0; 
                stored_data_in <= data_in; 

            end else if (bits_sent <= DATA_WIDTH) begin
                if (clk_out_count == DATA_HALF_PERIOD - 1) begin
                    data_clk_out <= 1; 
                    clk_out_count <= clk_out_count + 1; 
                end else if (clk_out_count == (DATA_HALF_PERIOD << 1) - 1) begin 
                    if (bits_sent < DATA_WIDTH) begin 
                        data_out <= stored_data_in[DATA_WIDTH - 1 - bits_sent]; 
                    end else begin
                        sel_out <= 1'b1;
                    end

                    data_clk_out <= 1'b0; 
                    
                    clk_out_count <= 1'b0; 
                    bits_sent <= bits_sent + 1; 
                end else begin 
                    clk_out_count <= clk_out_count + 1; 
                end

            end else begin 
                data_out <= 1'b0; 
                data_clk_out <= 1'b0; 
                sel_out <= 1'b1;
            end
        end
    end
endmodule
`default_nettype wire // prevents system from inferring an undeclared logic (good practice)
