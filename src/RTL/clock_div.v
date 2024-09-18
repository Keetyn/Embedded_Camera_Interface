module clock_div #(parameter N=10) (input rst, clk_in, output reg clk_out);

    reg [ $clog2 (N)-1:0 ] count;

    always @(posedge clk_in or negedge rst) begin
        if(!rst) begin
            clk_out <= 0;
            count <= 0;
        end else begin
            if (count==N) begin
                clk_out <= ~clk_out;
                count<= 0;
            end else
                count <= count + 1;
            end 
    end
endmodule


