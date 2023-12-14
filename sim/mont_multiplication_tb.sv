`timescale 1ns/1ps
`default_nettype none
module mont_multiplication_tb();
    localparam WIDTH = 512;
    logic clk_in;
    logic rst_in;
    logic [WIDTH-1:0] a_mont, b_mont, N, N_prime, x_out;
    logic [WIDTH:0] R;
    logic [WIDTH-1:0] expected_product, expected_result; //expected mont product and regular product, respectively
    logic [WIDTH*2:0] dirty_product; // contains the extra R factor
    logic [WIDTH-1:0] mont_product, product;
    mont_reduction #(.WIDTH(WIDTH))
        uut1(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .x_mont(dirty_product),
        .N(N),
        .R(R),
        .N_prime(N_prime),
        .x_out(mont_product)
    );
    mont_reduction #(.WIDTH(WIDTH))
        uut2(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .x_mont(mont_product),
        .N(N),
        .R(R),
        .N_prime(N_prime),
        .x_out(product)
    );
  always begin
      #5;
      clk_in = !clk_in;
  end
  initial begin
    $dumpfile("mont_multiplication_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,mont_multiplication_tb);
    $display("Starting Sim");
    clk_in = 0;
    rst_in = 0;
    $display("Testing multiplication of montgomery form numbers and converting to natural numbers");
    $display("Testing small numbers");
    R = 17'b1_0000_0000_0000_0000;
    N = 33227;
    N_prime = 39907;
    a_mont = (46 * R) % N;
    b_mont = (89 * R) % N;
    dirty_product = a_mont * b_mont;
    expected_product = 29586;
    expected_result = 4094;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    #80;
    if (mont_product == expected_product && product == expected_result) begin
        $display("Pass for small numbers");
    end else begin
      $display("Fail for small numbers");
      $display("expected \n %d\n for mont product, got \n%d", expected_product,mont_product);
      $display("expected \n %d\n for product, got \n%d", expected_result,product);
    end
    
    $display("Testing larger numbers");
    R = 2**512;
    N = 8446001084112110468007350899866059366449315229085619820000217473402760874334633786644317357840696578249028889585050688594982676710791149734896799707926013;
    N_prime = 17375175145035608609196778197953689598466863183139321616628855686527641584973423814770511815545299399600120723844078402737132859669623427881113829661259605;
    a_mont = (82289494155958622552101842259948196324913095467108646453504357986875686437490 * R) % N;
    b_mont = (82289494155958622552101842259948196324913095467108646453504357986875686437420 * R) % N;
    dirty_product = a_mont * b_mont;
    expected_product = 5255405100454035692691666349690643048154562890434481021356004637237504880308510202387268126354942230128949133533022942093680687941711762045999614719656946;
    expected_result = 6771560848443548293821990420426876433441733647190669695674323708617801635620227848081067321067936006208614918009833983778634679286921464268002629626875800;
    #80;
    if (mont_product == expected_product && product == expected_result) begin
        $display("Pass for big numbers");
    end else begin
      $display("Fail for big numbers");
    end

    $display("simulation done");
    $finish;
  end
endmodule

`default_nettype wire