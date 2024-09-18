module uart_tx(
                input wire rst,
                input wire clk,
                input wire send,
                output reg cts,
                output reg txd,
                input wire [7:0] data
              );

integer bit_count;
reg busy;
reg[9:0] data_reg;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        busy <=0;
        txd <=1;
        cts<=1;
        bit_count<=0;
    end else if (send==1 & busy==0) begin
        busy<=1;
        cts<=0;
        data_reg<={1'b1, data[7:0], 1'b0};
        bit_count<=0;
    end else if (busy==1) begin
        txd<=data_reg[0];
        data_reg<={1'b1, data_reg[9:1]};
        if (bit_count==10) begin
            busy<=0;
            cts<=1;
        end
        bit_count<=bit_count+1;
    end
end
endmodule