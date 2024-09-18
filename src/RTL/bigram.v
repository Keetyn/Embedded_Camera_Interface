module bigram(input [15:0] ram_addr,
               input [15:0] ram_din,
               output reg [15:0] ram_dout,
               input ram_wren,
               input clk_ram
               );
/*
    This module combines all four of the SPRAM primitives in an ICE40 FPGA 
    in depth to expand the memory from 16K x 16 or 32KB
    to 64K x 16 or 128KB
*/


//----------------------Instantiations----------------------------------------------------

wire [15:0] ram1_dout;
wire [15:0] ram2_dout;
wire [15:0] ram3_dout;
wire [15:0] ram4_dout;

reg ram1_wren;
reg ram2_wren;
reg ram3_wren;
reg ram4_wren;

//instantiating all of the SPRAM modules on the FPGA
//all connections are shared or eqeuivalent
//except for WREN (write enable) and DOUT (data out)
SB_SPRAM256KA spram1
        (
          .ADDRESS(ram_addr),
          .DATAIN(ram_din),
          .MASKWREN(4'b1111),
          .WREN(ram1_wren),
          .CHIPSELECT(1'b1),
          .CLOCK(clk_ram),
          .STANDBY(1'b0),
          .SLEEP(1'b0),
          .POWEROFF(1'b1),
          .DATAOUT(ram1_dout)
        );  

SB_SPRAM256KA spram2
        (
          .ADDRESS(ram_addr),
          .DATAIN(ram_din),
          .MASKWREN(4'b1111),
          .WREN(ram2_wren),
          .CHIPSELECT(1'b1),
          .CLOCK(clk_ram),
          .STANDBY(1'b0),
          .SLEEP(1'b0),
          .POWEROFF(1'b1),
          .DATAOUT(ram2_dout)
        );

SB_SPRAM256KA spram3
        (
          .ADDRESS(ram_addr),
          .DATAIN(ram_din),
          .MASKWREN(4'b1111),
          .WREN(ram3_wren),
          .CHIPSELECT(1'b1),
          .CLOCK(clk_ram),
          .STANDBY(1'b0),
          .SLEEP(1'b0),
          .POWEROFF(1'b1),
          .DATAOUT(ram3_dout)
        );
    
SB_SPRAM256KA spram4
        (
          .ADDRESS(ram_addr),
          .DATAIN(ram_din),
          .MASKWREN(4'b1111),
          .WREN(ram4_wren),
          .CHIPSELECT(1'b1),
          .CLOCK(clk_ram),
          .STANDBY(1'b0),
          .SLEEP(1'b0),
          .POWEROFF(1'b1),
          .DATAOUT(ram4_dout)
        );  



//-----------------------MUXing / Logic Section--------------------------------------------------


//setting up the select used for the muxing case statement
//essentially just uses the most significant bits of the ram address
//to select which ram module to access
wire [1:0] sel;
assign sel[1:0] = ram_addr[15:14];

//combinational always block
always @* begin
    case(sel)

        //use ram1 when two most significant bits of addres are zero in decimal
        2'b00 : begin
            ram1_wren <= ram_wren; //set ram1 to actively use the input write enable
            ram2_wren <= 1'b0; //set ram2 to read mode so data meant for ram1 won't be written to ram2
            ram3_wren <= 1'b0;
            ram4_wren <= 1'b0;
            ram_dout <= ram1_dout; //only output the values from ram1
        end

        //use ram2 when two most significant bits of addres are one in decimal
        2'b01 : begin
            ram1_wren <= 1'b0;
            ram2_wren <= ram_wren;
            ram3_wren <= 1'b0;
            ram4_wren <= 1'b0;
            ram_dout <= ram2_dout;
        end

        //use ram3 when two most significant bits of addres are two in decimal
        2'b10 : begin
            ram1_wren <= 1'b0;
            ram2_wren <= 1'b0;
            ram3_wren <= ram_wren;
            ram4_wren <= 1'b0;
            ram_dout <= ram3_dout;
        end

        //use ram4 when two most significant bits of addres are three in decimal
        2'b11 : begin
            ram1_wren <= 1'b0;
            ram2_wren <= 1'b0;
            ram3_wren <= 1'b0;
            ram4_wren <= ram_wren;
            ram_dout <= ram4_dout;
        end
    endcase 
end
endmodule