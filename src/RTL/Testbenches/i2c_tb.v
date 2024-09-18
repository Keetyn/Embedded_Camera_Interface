`timescale 1 ns / 1 ns
module i2c_tb;

  // Parameters

  //Ports
  wire  SDA;
  wire  SCL;
  reg  rst;
  reg clk;
  wire  GLED;
  wire  BLED;
  wire  RLED;

  i2c  i2c_inst (
    .SDA(SDA),
    .SCL(SCL),
    .rst(rst),
    .clk_FSM(clk)
  );

  initial begin
    clk = 0;
    forever begin
    #1 clk = ~clk;
 end end

 initial begin
    rst=1;
    #5
    rst=0;
    #5
    rst=1;
    #3000
    $finish;
 end



 initial begin
    $dumpfile("i2c_tb.vcd");
    $dumpvars(0, i2c_tb);
 end



endmodule
