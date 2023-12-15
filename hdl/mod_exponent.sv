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
    input wire ready_in, // downstream module ready to accept results
    output logic [WIDTH-1:0] c_out,
    output logic valid_out,
    output logic busy_out
    );
    typedef enum {IDLE=0,COMPUTING=1,DONE=2,UPDATE_PRODUCT=3,REDUCE=5,UPDATE_BASE=4,NEXT=6,LAST_REDUCTION=7,WAITING=8,MULTIPLIER_START=9,MULTIPLIER_DONE=10} states;
    states state;
    logic [WIDTH-1:0] running_product, current_base;
    logic [$clog2(WIDTH)-1:0] current_index;
    logic [WIDTH*2:0] reduce_input1, reduce_input2;
    logic [WIDTH-1:0] reduce_output1, reduce_output2;
    logic finished, finished2; // used to keep track of the reductions finishing
    // multipliers
        logic mult_valid_in, mult_valid_out, mult_busy;
    logic [WIDTH-1:0] mult_a, mult_b;
    logic [WIDTH*2-1:0] mult_out;

    multiplier #(.WIDTH(WIDTH))
     multiplier(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .a_in(mult_a),
        .b_in(mult_b),
        .valid_in(mult_valid_in),
        .c_out(mult_out),
        .valid_out(mult_valid_out),
        .busy_out(mult_busy)
     );
    logic [WIDTH-1:0] mark_a, mark_b;
    logic [WIDTH*2-1:0] mark_out;
    logic markiplier_valid_in, markiplier_valid_out, markiplier_busy;
    multiplier #(.WIDTH(WIDTH))
     markiplier(.clk_in(clk_in),
                .rst_in(rst_in),
                .a_in(mark_a),
                .b_in(mark_b),
                .valid_in(markiplier_valid_in),
                .c_out(mark_out),
                .valid_out(markiplier_valid_out),
                .busy_out(markiplier_busy)
                );

    // Used to keep track of the current base
    logic reduction_valid_in, reduction_valid_out, reduction_busy;
    mont_reduction #(.WIDTH(WIDTH))
     reduction(.clk_in(clk_in),
                .rst_in(rst_in),
                .x_mont(mult_out),
                .N(modulo),
                .R(R),
                .N_prime(inv_modulo),
                .valid_in(mult_valid_out),
                .x_out(reduce_output1),
                .valid_out(reduction_valid_out),
                .busy_out(reduction_busy)
     );
    // Used to keep track of the running product, and then the final reduction
    logic reduction2_valid_in, reduction2_valid_out, reduction2_busy;
    mont_reduction #(.WIDTH(WIDTH))
     reduction2(.clk_in(clk_in),
                .rst_in(rst_in),
                .x_mont(mark_out),
                .N(modulo),
                .R(R),
                .N_prime(inv_modulo),
                .valid_in(markiplier_valid_out),
                .x_out(reduce_output2),
                .valid_out(reduction2_valid_out),
                .busy_out(reduction2_busy)
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
            finished <= 0;
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
                        finished <= 0;
                    end
                end
                UPDATE_BASE: begin
                    mult_a <= current_base;
                    mult_b <= current_base;
                    mult_valid_in <= 1'b1;
                    state <= REDUCE;
                end
                UPDATE_PRODUCT: begin
                    mult_a <= current_base;
                    mult_b <= current_base;
                    mult_valid_in <= 1'b1;
                    mark_a <= current_base;
                    mark_b <= running_product;
                    markiplier_valid_in <= 1'b1;
                    state <= REDUCE;
                end
                REDUCE: begin
                    if (exponent[current_index] == 1) begin
                        if (reduction_valid_out) begin
                            finished <= 1'b1;
                            current_base <= reduce_output1;
                        end
                        if (reduction2_valid_out) begin
                            finished2 <= 1'b1;
                            running_product <= reduce_output2;
                        end
                        if (finished == 1'b1 && finished2 == 1'b1) begin
                            state <= NEXT;
                        end
                        mult_valid_in <= 0;
                        markiplier_valid_in <= 0;
                    end else begin
                        if (reduction_valid_out) begin
                            finished <= 1'b1;
                            current_base <= reduce_output1;
                        end
                        if (finished) begin
                            state <= NEXT;
                        end
                        mult_valid_in <= 0;
                    end
                end
                NEXT: begin
                    //setup logic for the next iteration
                    current_index <= current_index + 1;
                    state <= COMPUTING;
                    finished <= 0;
                end
                LAST_REDUCTION: begin
                    mark_a <= running_product; // terribly slow but oops
                    mark_b <= 1'b1;
                    markiplier_valid_in <= 1'b1;
                    state <= WAITING;
                end
                WAITING: begin
                    if (reduction2_valid_out) begin
                        c_out <= reduce_output2;
                        valid_out <= 1;
                        busy_out <= 0;
                        state <= DONE;
                    end
                end
                DONE: begin
                    if (ready_in) begin 
                        state <= IDLE;
                        valid_out <= 0;
                    end
                end
            endcase
        end
    end
    
endmodule
`default_nettype wire ;