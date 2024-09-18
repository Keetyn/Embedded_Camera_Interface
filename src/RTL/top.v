module top #(parameter SECTION=1)
          (input rst,
           output SDA,
           output SCL,
           output reg IRLED,
           input rxd,
           output txd,
           output reg TRIG,
           output wire MCLK,
           input wire PCLK,
           input wire [7:0] cam_data,
           output BLED,
           output GLED,
           output RLED);


//------------------Clocking Section--------------------------------------------
// int_osc set at 12MHz

           SB_HFOSC u_hfosc (
            .CLKHFPU(1'b1),
            .CLKHFEN(1'b1),
            .CLKHF(int_osc)
        );
        //sets divider at 2, 48MHz / 2 = 24MHz
        defparam u_hfosc.CLKHF_DIV = "0b01";
        wire int_osc;

        clock_div u7(.rst(rst), .clk_in(int_osc), .clk_out(clock_MCLK));
        defparam u7.N=1;
        wire clock_MCLK;

        assign MCLK = clock_MCLK;
        //u6 with a division of 96 (int_osc / 96*2) generates a 125kHz clock for I2C
        clock_div u6(.rst(rst), .clk_in(int_osc), .clk_out(clk_i2C));
        defparam u6.N=192;
        wire clk_i2C;

    /*
        clock_div u7(.rst(rst), .clk_in(int_osc), .clk_out(clk_FSM));
        defparam u7.N=100000;
        wire clk_FSM;
    */

        //u8 with a division of 1250 (int_osc / 1250*2) generates 9600Hz clock for UART_TX
        clock_div u8(.rst(rst), .clk_in(int_osc), .clk_out(clk_uart_tx));
        defparam u8.N=1250;


        //u9 with a division of 80 (int_osc / 80*2) generates 150kHz clock for UART_RX
        clock_div u9(.rst(rst), .clk_in(int_osc), .clk_out(clk_uart_rx));
        defparam u9.N=80;



//---------------LED Driver setup---------------------------------------------
reg green, blue, red; //LED on/off control bits

// LED Driver Instantiation
SB_RGBA_DRV u1(.RGBLEDEN(1'b1),
               .CURREN(1'b1),
               .RGB0PWM(green),
               .RGB1PWM(blue),
               .RGB2PWM(red),
               .RGB0(GLED),
               .RGB1(BLED),
               .RGB2(RLED));

defparam u1.RGB0_CURRENT = "0b001111";
defparam u1.RGB1_CURRENT = "0b001111";
defparam u1.RGB2_CURRENT = "0b001111";

//-------------------------------i2C Setup-------------------------------

//this I2C module sends data from the registers.txt file on reset
//It is hardcoded with the address for the camera on the himax shield
i2c u2( .rst(rst),
        .clk(clk_i2C),
        .SDA(SDA),
        .SCL(SCL));

//-------------------------------SPRAM Setup---------------------------------


reg [15:0] ram_addr;
reg [15:0] ram_din;
wire [15:0] ram_dout;

reg ram_wren;

//this ram module combines all 4 built in SPRAM primitives in the ICE40 FPGA
//and does all the necessary MUXing to create a 64K x 16 RAM module
bigram u3(.ram_addr(ram_addr),
          .ram_din(ram_din),
          .ram_dout(ram_dout),
          .ram_wren(ram_wren),
          .clk_ram(int_osc));



//-----------------------------UART Setup------------------------------------
wire clk_uart_rx, clk_uart_tx; //Clock signals for each module
wire uart_cts, rx_done, rst; //uart clear to send, uart data reception done, reset
reg uart_send, uart_dtr; //send uart data, uart ready to receive
wire [7:0] data_rx; //sends received uart_rx data
reg [7:0] data_tx; //receives uart_tx data to transmit

            uart_tx u4( .rst(rst),
                        .clk(clk_uart_tx),
                        .send(uart_send),
                        .data(data_tx),
                        .txd(txd),
                        .cts(uart_cts));

            uart_rx u5( .rst(rst),
                        .clk(clk_uart_rx),
                        .rxd(rxd),
                        .dtr(uart_dtr),
                        .data(data_rx),
                        .rx_done(rx_done));


//-------------------------------State Machine-------------------------------


/* Camera notes
    with register 0x3060 set to 0x29 the PCLK or data transfer clock is set
    to be MCLK/4 in MCLK mode. and is gated such that it is not oscillating
    when there is no data being transferred with the clock divider above,
    int_osc is 8 x MCLK in frequency to allow a cushion for the logic timing

    We are also using 8 bit mode so there should be one pixel transfered
    for each PCLK cycle

    With this in mind we can either clock in new data on the falling edges of
    PCLK or clock in new data every other rising edge of MCLK



    need:
        SDA
        SCL
        output reg TRIG
        output wire MCLK
        input wire PCLK
        input wire cam_data[7:0]

    also for IR LEDs need:
        IRLED
        pin13


    one state machine, that waits for uart then triggers the camera
    waits for pclk to go from low to high then clocks in data, use  i as
    a counter to count 324 * 324 = 104976 bytes and load data into ram
    every other byte

    once this is done pull data from ram once again using i as a counter to
    pull out 104976 bytes and transmit it through UART
    must separate data into two bytes as RAM data comes in a word of 16 bits

    once this is done go back to initial state and wait for UART
*/


reg [3:0] state; //setting up FSM states
integer i;
reg [15:0] preg;
reg check;

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
           S11 = 4'b1011;

generate
    if(SECTION==1) begin
        always@(posedge int_osc or negedge rst) begin
            if(!rst) begin
                state<=S0;
                red<=0; green<=0; blue<=0; //turn off LED
                uart_send<=0; //reset uart transmitter
                uart_dtr<=1; //turn receiver ready on
                data_tx<=8'h00; // clear transmit data
                ram_addr <= 0;
                ram_din <= 0;
                ram_wren <= 0;
                IRLED <= 1;
                TRIG <= 0;
            end else begin
                case(state)
                    S0: begin
                        uart_dtr<=1; //data terminal ready on
                        if(rx_done) begin //when reception is done
                            state<= S1;
                        end
                    end
                    S1: begin
                        uart_dtr<=0; //data terminal ready off
                        if(uart_cts) begin //if tx is clear to send
                            uart_send<=1; //set send high
                            data_tx <= data_rx; //set tx data to rx'd data
                            state<= S2;
                        end 
                        red<=0; green<=0; blue<=1;
                    end
                    S2: begin
                        if(!uart_cts) begin //wait for CTS to go low to ensure tx module receives send signal
                            uart_send<=0; //set uart_send low to avoid double sending
                            state<=S3;
                        end
                        red<=0; green<=1; blue<=0;
                    end
                    S3: begin
                        if(uart_cts) begin //when sending is done
                            if(data_tx == 8'h69) begin //check for enter key being pressed
                                state<=S0;
                                IRLED <= !IRLED;
                            end else if(data_tx == 8'h66) begin
                                state<= S4;
                                TRIG <= 1;
                            end else begin
                                uart_dtr<=1; //set data terminal ready
                                state<=S0;
                            end
                        end
                        red<=1; green<=0; blue<=0;
                    end
                    S4: begin
                        ram_wren <= 0;
                        if(PCLK == 1) begin //wait for PCLK to go high for new data
                            preg[7:0] <= cam_data; //read in first byte
                            check <= 1; //set check high
                        end else if(check==1) begin //wait for check high and PCLK low to ensure second byte doesn't capture first byte
                           check<=0;
                           state<=S5; 
                        end
                        red<=0; green<=0; blue<=1;
                    end
                    S5: begin
                        ram_wren <= 0;
                        if(PCLK==1) begin //wait for PCLK high for new data
                            preg[15:8] <= cam_data; //read in second byte
                            state<=S6;
                        end
                        red<=0; green<=1; blue<=0;
                    end
                    S6: begin
                        if(i<52488) begin //if frame is still on going send data to ram
                                            //might change number to 51200
                            ram_din<=preg;
                            ram_addr<=i;
                            ram_wren <= 1;
                            i<=i+1;
                            state <= S7;
                        end else begin //once frame is done
                            i<=0;
                            state<=S8;
                        end
                        red<=1; green<=0; blue<=0;
                    end
                    S7: begin
                        state<=S4; //extra clock cycle to ensure same data isn't copied into memory
                    end
                    S8: begin
                        if(i<52488) begin //while frame is still on going transmit through uart
                                          //might change number to 51200
                            ram_addr <= i;
                            if(uart_cts) begin
                                data_tx <= ram_dout[7:0];
                                uart_send<=1;
                                i<=i+1;
                                state<=S9;
                            end
                        end else begin
                            state <= S0;
                            i<=0;
                        end
                        red<=1; green<=1; blue<=1;
                    end
                    S9: begin
                        if(!uart_cts) begin
                            uart_send <= 0;
                            state <= S10;
                        end
                    end
                    S10: begin
                        if(uart_cts) begin
                            data_tx <= ram_dout[15:8];
                            uart_send<=1;
                            state<=S11;
                        end
                    end
                    S11: begin
                        if(!uart_cts) begin
                            uart_send<=0;
                            state<=S8;
                        end
                    end
                endcase

            end
        end

    end else if(SECTION==2) begin
        always@(posedge clk_FSM or negedge rst) begin
            if(!rst) begin

            end else begin
                red<=!red;
            end
        end

    end else if(SECTION==3) begin
        always@(posedge clk_FSM or negedge rst) begin
            if(!rst) begin

            end else begin
                red<=!red;
            end
        end

    end

endgenerate
endmodule
