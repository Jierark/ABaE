`timescale 1ns/1ps
`default_nettype none
module mod_exponent_largetb();
    localparam WIDTH = 512;
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
    $dumpfile("mod_exponent_largetb.vcd");
    $dumpvars(0,mod_exponent_largetb);
    $display("Starting Sim");
    clk_in = 0;
    rst_in = 0;
    exponent = 11955249013037732955415475167712015131498861761303123691967550247200664136114283874768147558084758760338234469850377626456638526938872768868946969494346685;
    modulo = 4113369699522490201139616810280894218132750113931120371300191042499995904753654608484764203252363554518939926320318226484786991340827671431724284699241607;
    expected = 2383272142171528110174159276556634133222900485768223220176278705955367968110218869997953781294772551583092062415486248952789549111615838929652835582463195;
    R = 2 ** WIDTH;
    // CHANGE BELOW EVERYTIME WIDTH CHANGES
    inv_modulo = 1439597541152963842429157698102422918192473540062430083699502068837878612745857800582206328732692516534356768912074512457967792656615706296136858734729527; 
    // base = (69 * R) % modulo; <-- compute manually and assign
    // start_product = R % modulo; <-- same with this
    base = 3372707849804203220370718384509147371198710386949412960932300872489085714491232993548249752386100666494115998578056857834077969961191005176742602352064892;
    start_product = 1067698831375126496155174567363163473081115478799032263822988316221776315812583151347581688409812764133212079225531371399392908789463555651260794908359275;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    valid_in = 1;
    #10;
    valid_in = 0;
    #100000;
    if (out == expected) begin
        $display("wow it works");
    end else begin
      $display("something didn't go right, here's a debug value");
      $display("%d", out);
    end
    $display("Sim Finished");
    $finish;
        exponent = 8;
    modulo = 61;
    expected = 20;
  end
endmodule

`default_nettype wire