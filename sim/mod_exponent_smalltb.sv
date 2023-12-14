`timescale 1ns/1ps
`default_nettype none
module mod_exponent_smalltb();
    localparam WIDTH = 16;
    logic clk_in;
    logic rst_in;
    logic [WIDTH-1:0] base, exponent, modulo, inv_modulo, start_product;
    logic [WIDTH:0] R;
    logic valid_in;
    logic [WIDTH-1:0] out;
    logic valid_out, error_out, busy_out;
    logic [WIDTH-1:0] expected;

    mod_exponent #(.WIDTH(WIDTH))
        uut(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .base(base),
        .exponent(exponent),
        .modulo(modulo),
        .inv_modulo(inv_modulo),
        .R(R),
        .start_product(start_product),
        .valid_in(valid_in),
        .c_out(out),
        .valid_out(valid_out),
        .busy_out(busy_out)
    );
  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock (this might be too fast but we'll see)
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("mod_exponent_smalltb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,mod_exponent_smalltb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    exponent = 8;
    modulo = 61;
    expected = 20;
    R = 2 ** WIDTH;
    // CHANGE BELOW EVERYTIME WIDTH CHANGES
    inv_modulo = 38677; 
    // base = (69 * R) % modulo; <-- compute manually and assign
    // start_product = R % modulo; <-- same with this
    base = 54;
    start_product = 22;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    valid_in = 1;
    #10;
    valid_in = 0;
    #10000000
    if (out == expected) begin
        $display("wow it works");
    end else begin
      $display("something didn't go right, here's a debug value");
      $display("%d", out);
    end
    $display("Sim Finished");
    $finish;
  end
endmodule

`default_nettype wire