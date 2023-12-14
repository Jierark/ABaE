`timescale 1ns/1ps
`default_nettype none
module mont_reduction_tb();
    localparam WIDTH = 512;
    logic clk_in;
    logic rst_in;
    logic [WIDTH-1:0] x_mont, N, N_prime, x_out;
    logic [WIDTH:0] R;
    logic [WIDTH-1:0] expected;
    logic valid_in, valid_out, busy_out;
    mont_reduction #(.WIDTH(WIDTH))
        uut(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .x_mont(x_mont),
        .N(N),
        .R(R),
        .N_prime(N_prime),
        .valid_in(valid_in),
        .x_out(x_out),
        .valid_out(valid_out),
        .busy_out(busy_out)
    );
  always begin
      #5;
      clk_in = !clk_in;
  end
  initial begin
    $dumpfile("mont_reduction_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,mont_reduction_tb);
    $display("Starting Sim");
    clk_in = 0;
    rst_in = 0;
    $display("Testing reduction to natural numbers from Montgomery Form");
    // Adjust width to 16 for this to work
    // $display("Testing small numbers");
    // R = 17'b1_0000_0000_0000_0000;
    // N = 33227;
    // N_prime = 39907;
    // x_mont = (46 * R) % N;
    // expected = 46;
    // #10;
    // rst_in = 1;
    // #10;
    // rst_in = 0;
    // valid_in <= 1;
    // #10;
    // valid_in <= 0;
    // #9000;
    // if (x_out == expected) begin
    //     $display("Pass for small numbers");
    // end else begin
    //   $display("Fail for small numbers");
    //   $display("Here's a debug value");
    //   $display(x_out);
    // end
    
    $display("Testing larger numbers");
    R = 2**512;
    N = 8446001084112110468007350899866059366449315229085619820000217473402760874334633786644317357840696578249028889585050688594982676710791149734896799707926013;
    N_prime = 17375175145035608609196778197953689598466863183139321616628855686527641584973423814770511815545299399600120723844078402737132859669623427881113829661259605;
    x_mont = (82289494155958622552101842259948196324913095467108646453504357986875686437490 * R) % N;
    expected = 82289494155958622552101842259948196324913095467108646453504357986875686437490;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    valid_in <= 1;
    #10;
    valid_in <= 0;
    #9000;
    if (x_out == expected) begin
        $display("Pass for large numbers");
    end else begin
      $display("Fail for large numbers");
      $display("Here's a debug value");
      $display(x_out);
    end
    $display("Sim Finished");
    $finish;
  end
endmodule

`default_nettype wire