module uart_rx(
                input wire rst,
                input wire clk,
                input wire rxd,
                input wire dtr,
                output reg rx_done,
                output reg [7:0] data
              );

reg[2:0] state;
reg[7:0] s_reg;
integer samples, bit_count;

localparam idle=3'b000, start=3'b001, s_data=3'b010, stop=3'b011, parity=3'b100;

always @(posedge clk or negedge rst) begin: FSM

  if (!rst) begin
    state <= idle;
    samples <= 0;
    bit_count <= 0;
    rx_done <= 0;
    data <= 8'h00;
  end else begin
    case (state)
      idle  : begin
        if (rxd==0 & dtr==1) begin
          state<=start;
          rx_done<=0;
          samples<=0;
        end else state <= idle;
        if (dtr==0) rx_done<=0;
      end
      start  : begin
        if(samples==7) begin
          state<=s_data;
          samples<=0;
          bit_count<=0;
        end else samples <= samples +1;
      end
      s_data : begin
        if (samples==15) begin
          s_reg<={rxd, s_reg[7:1]};
          samples<=0;
          bit_count<=bit_count+1;
        end else samples<=samples+1;
        
          if (bit_count==8) begin
            state<=stop;
            samples<=0;
          end else state<=s_data;
      end
      parity  : begin
        if (samples==15) begin
          state<=stop;
          samples<=0;
        end else samples<=samples+1;
      end
      stop  : begin
        if (samples==15) begin
          rx_done<=1;
          data<=s_reg;
        end else samples<=samples+1;
        if(rx_done==1 && rxd==1)begin
          state<=idle;
        end
      end
      default : begin
        
      end
    endcase 
  end
end
//data_parity <= (s_reg(0) ^ s_reg(1) ^ s_reg(2) ^ s_reg(3) ^ s_reg(4) ^ s_reg(5) ^ s_reg(6) ^ s_reg(7));
endmodule
