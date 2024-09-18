module i2c
            (output reg SDA,
             input wire clk,
             output reg SCL,
             input wire rst);

//---------------State Machine----------------------------------------------------
localparam S0=4'b0000, 
           S1=4'b0001, 
           S2=4'b0010, 
           S3=4'b0011, 
           S4=4'b0100, 
           S5=4'b0101, 
           S6=4'b0110, 
           S7=4'b0111, 
           S8=4'b1000, 
           S9=4'b1001, 
           S10 = 4'b1010, 
           S11 = 4'b1011,
           S12 = 4'b1100;

           
reg [3:0] state; //setting up FSM states
reg enable;
integer bit_count, reg_count, i, tick_count;

reg [23:0] rom [0:4]; //stores register data
reg [7:0] sreg;


initial begin
    $readmemh("registers.txt", rom);
end

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        SCL<=1;
    end else if(enable) begin
        SCL <= !SCL;
    end else begin
        SCL<=1;
    end
end 


always @(negedge clk or negedge rst) begin
    if(!rst) begin
        SDA<=1;
        enable<=0;
        state<= S0;
        bit_count<=0;
        tick_count<=0;
        reg_count<=0;
    end else begin
        case(state)
            S0: begin
                sreg <= {8'h24, 1'b0};
                bit_count<=0;
                tick_count<=0;
                SDA<=0;
                enable<=1;
                state<=S1;
            end
            S1: begin
                SDA<=sreg[7];
                if(tick_count==1) begin
                    sreg <= {sreg[6:0], 1'b0};
                    if(bit_count==7) begin
                        bit_count <= 0;
                        state <= S2;
                    end else begin
                        bit_count <= bit_count + 1;
                        state <= S1;
                    end
                    tick_count <= 0;
                end else begin
                    tick_count <= tick_count + 1;
                end
            end
            S2: begin
                SDA <= 0;
                if(tick_count == 1) begin
                    sreg <= rom[reg_count][23:16];
                    bit_count<=0;
                    tick_count <= 0;
                    state<= S3;
                end else begin
                    tick_count <= tick_count + 1;
                end
            end
            S3: begin
                SDA <= sreg[7];
                if(tick_count == 1) begin
                    sreg <= {sreg[6:0], 1'b0};
                    if(bit_count==7) begin
                        bit_count<=0;
                        state<=S4;
                    end else begin
                        bit_count <= bit_count + 1;
                        state<= S3;
                    end
                    tick_count<=0;
                end else begin
                    tick_count <= tick_count + 1;
                end 
            end
            S4: begin
                SDA <= 0;
                if(tick_count == 1) begin
                    sreg <= rom[reg_count][15:8];
                    bit_count<=0;
                    tick_count <= 0;
                    state<= S5;
                end else begin
                    tick_count <= tick_count + 1;
                end
            end
            S5: begin
                SDA <= sreg[7];
                if(tick_count == 1) begin
                    sreg <= {sreg[6:0], 1'b0};
                    if(bit_count==7) begin
                        bit_count<=0;
                        state<=S6;
                    end else begin
                        bit_count <= bit_count + 1;
                        state<= S5;
                    end
                    tick_count<=0;
                end else begin
                    tick_count <= tick_count + 1;
                end 
            end
            S6: begin
                SDA <= 0;
                if(tick_count == 1) begin
                    sreg <= rom[reg_count][7:0];
                    bit_count<=0;
                    tick_count <= 0;
                    state<= S7;
                end else begin
                    tick_count <= tick_count + 1;
                end
            end
            S7: begin
                SDA <= sreg[7];
                if(tick_count == 1) begin
                    sreg <= {sreg[6:0], 1'b0};
                    if(bit_count==7) begin
                        bit_count<=0;
                        state<=S8;
                    end else begin
                        bit_count <= bit_count + 1;
                        state<= S7;
                    end
                    tick_count<=0;
                end else begin
                    tick_count <= tick_count + 1;
                end 
            end
            S8: begin
                SDA <= 0;
                if(tick_count == 1) begin
                    sreg <= 8'h00;
                    bit_count<=0;
                    tick_count <= 0;
                    state<= S9;
                end else begin
                    tick_count <= tick_count + 1;
                end
            end
            S9: begin
                SDA<= 0;
                enable<= 0;
                state <= S10;
            end
            S10: begin
                if(reg_count<5) begin //4 for given reg values, 5 for test pattern
                    reg_count <= reg_count + 1;
                    SDA<= 1;
                    state<=S11;
                end else begin
                    state <= S11;
                    SDA<=1;
                end
            end
            S11: begin
                state<=S12;
            end
            S12: begin
                state<=S0;
            end
        endcase
    end
end
endmodule