`timescale 1ns/1ps
`default_nettype none
module modular_inverse_tb();
    logic clk_in;
    logic rst_in;
    logic [511:0] num, base;
    logic valid_in;
    logic [511:0] out;
    logic valid_out, error_out, busy_out;
    logic [511:0] expected;

    modular_inverse #(.WIDTH(512))
        uut(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .a_in(num),
        .base(base),
        .valid_in(valid_in),
        .b_out(out),
        .valid_out(valid_out),
        .busy_out(busy_out),
        .error_out(error_out)
    );
  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock (this might be too fast but we'll see)
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("modular_inverse_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,modular_inverse_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    num = 11771277631567105112429390968344039472017655878094069789596899075379556637591777263612685912638072676971202571005125788549738055042212111622006381650085741;
    base = 7038747235645766647601534062230126447880082574479551592729267315028956456991270137047483167243727743721697091099593982762286861266825761539834903570699207;
    // Thank god for python, I have no idea how I was gonna read 128 hex digits
    expected = 3026486573922135933347162266434197347000801954591955628451452122615628358378622438321873052256261617382380550515818316432815442076960637096436427767588780;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    valid_in = 1;
    #10;
    valid_in = 0;
    while (~valid_out) begin
        #10;
    end
    #3000;
    if (out == expected) begin
        $display("wow it works");
    end
    $display("Sim Finished");
    $finish;
  end
endmodule

`default_nettype wire