`timescale 1ns/1ps
`default_nettype none

module mod_exponent #(parameter WIDTH = 512) (
    // Take a number and raise it to some power, mod another number
    // Base should already be converted to montgomery form
    input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] base,
    input wire [WIDTH-1:0] exponent,
    input wire [WIDTH-1:0] modulo,
    input wire [WIDTH-1:0] inv_modulo, //needed for montgomery
    input wire [WIDTH:0] R, //needed for montgomery
    input wire [WIDTH-1:0] start_product, //need the montgomery form of 1
    input wire valid_in,
    output logic [WIDTH-1:0] c_out,
    output logic valid_out,
    output logic busy_out
    );
    typedef enum {IDLE=0,COMPUTING=1,DONE=2,UPDATE_PRODUCT=3,REDUCE=5,UPDATE_BASE=4,NEXT=6,LAST_REDUCTION=7,WAITING=8} states;
    states state;
    logic [WIDTH-1:0] running_product, current_base;
    logic [$clog2(WIDTH)-1:0] current_index;
    logic [WIDTH*2:0] reduce_input1, reduce_input2;
    logic [WIDTH-1:0] reduce_output1, reduce_output2;
    logic [1:0] counter; // used for montgomery reduction
    // Used to keep track of the current base
    mont_reduction #(.WIDTH(WIDTH))
     reduction(.clk_in(clk_in),
                .rst_in(rst_in),
                .x_mont(reduce_input1),
                .N(modulo),
                .R(R),
                .N_prime(inv_modulo),
                .x_out(reduce_output1)
     );
    // Used to keep track of the running product, and then the final reduction
    mont_reduction #(.WIDTH(WIDTH))
     reduction2(.clk_in(clk_in),
                .rst_in(rst_in),
                .x_mont(reduce_input2),
                .N(modulo),
                .R(R),
                .N_prime(inv_modulo),
                .x_out(reduce_output2)
     );


    always_ff @(posedge clk_in) begin
        // Declare a running product
        // start with base
        // compute base ^ (2^i) by squaring the previous value
        // if bit i is true --> multiply running product by base ^ (2^i)
        // Increment i
        // repeat until reach end
        if (rst_in) begin
            running_product <= start_product;
            current_index <= 0;
            state <= IDLE;
            busy_out <= 0;
            counter <= 0;
            reduce_input1 <= 0;
            reduce_input2 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_in) begin
                        state <= COMPUTING;
                        running_product <= start_product;
                        current_index <= 0;
                        current_base <= base; 
                        busy_out <= 1;
                    end
                end 
                COMPUTING: begin
                    if (current_index == WIDTH-1) begin
                        state <= LAST_REDUCTION;
                    end else begin
                        if (exponent[current_index] == 1) begin
                            state <= UPDATE_PRODUCT;
                        end else begin
                            state <= UPDATE_BASE;
                        end
                        counter <= 0;
                    end
                end
                UPDATE_BASE: begin
                    reduce_input1 <= current_base * current_base;
                    state <= REDUCE;
                end
                UPDATE_PRODUCT: begin
                    reduce_input1 <= current_base * current_base;
                    reduce_input2 <= running_product * current_base;
                    state <= REDUCE;
                end
                REDUCE: begin
                    // just chill for 4 cycles until the reduction finishes
                    if (counter == 2'b11) begin
                        state <= NEXT;
                    end else begin
                        counter <= counter + 1;    
                    end
                end
                NEXT: begin
                    //setup logic for the next iteration
                    current_index <= current_index + 1;
                    current_base <= reduce_output1;
                    if (exponent[current_index] == 1) begin
                        running_product <= reduce_output2;
                    end
                    state <= COMPUTING;
                    counter <= 0;
                end
                LAST_REDUCTION: begin
                    reduce_input2 <= running_product;
                    counter <= 0;
                    state <= WAITING;
                end
                WAITING: begin
                    if (counter == 2'b11) begin
                        c_out <= reduce_output2;
                        valid_out <= 1;
                        busy_out <= 0;
                        state <= DONE;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                DONE: begin
                    state <= IDLE;
                    valid_out <= 0;
                end
            endcase
        end
    end
    
endmodule
`default_nettype wire ;