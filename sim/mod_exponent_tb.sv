`timescale 1ns/1ps
`default_nettype none
module mod_exponent_tb();
  // TODO: Adjust to work with larger sized logics
    localparam WIDTH = 10;
    logic clk_in;
    logic rst_in;
    logic [WIDTH-1:0] base, exponent, modulo;
    logic valid_in;
    logic [WIDTH-1:0] out;
    logic valid_out, error_out, busy_out;
    logic [WIDTH-1:0] expected;

    mod_exponent #(.WIDTH(10))
        uut(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .base(base),
        .exponent(exponent),
        .modulo(modulo),
        .valid_in(valid_in),
        .c_out(out),
        .valid_out(valid_out)
    );
  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock (this might be too fast but we'll see)
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("mod_exponent_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,mod_exponent_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    base = 69;
    exponent = 8;
    modulo = 54;
    // Thank god for python, I have no idea how I was gonna read 128 hex digits
    expected = 27;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    valid_in = 1;
    #10;
    valid_in = 0;
    #3000;
    if (out == expected) begin
        $display("wow it works");
    end
    $display("Sim Finished");
    $finish;
  end
endmodule

`default_nettype wire