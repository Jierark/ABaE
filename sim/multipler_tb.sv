`timescale 1ns/1ps
`default_nettype none
module multiplier_tb();
    localparam WIDTH = 256;
    logic clk_in;
    logic rst_in;
    logic [WIDTH-1:0] p, q;
    logic valid_in;
    logic [WIDTH*2-1:0] N;
    logic valid_out, busy_out;
    logic [WIDTH*2-1:0] expected;

    multiplier #(.WIDTH(WIDTH))
        uut(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .a_in(p),
        .b_in(q),
        .valid_in(valid_in),
        .c_out(N),
        .valid_out(valid_out),
        .busy_out(busy_out)
    );
  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock (this might be too fast but we'll see)
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("multiplier_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,multiplier_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    $display("Test with small numbers");
    p = 13;
    q = 23;
    expected = 299;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    valid_in = 1;
    #10;
    valid_in = 0;
    #3000; // Should only take 256 clock cycles to finish, but add some leeway just in case
    if (N == expected) begin
        $display("Test case passed");
    end else begin
        $display("Test failed");
    end
    $display("Test with larger numbers");
    p = 308113484502254276214653084379069091219;
    q = 193690634914747133184576417654126124729;
    expected = 59678696439036731833174790408137592454209857625042749229656692202628272654651;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    valid_in = 1;
    #10;
    valid_in = 0;
    #3000; // Should only take 256 clock cycles to finish, but add some leeway just in case
    if (N == expected) begin
        $display("Test case passed");
    end else begin
        $display("Test failed");
    end
    
    $display("Sim Finished");
    $finish;
  end
endmodule

`default_nettype wire