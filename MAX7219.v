module MAX7219 #(
    parameter Freq_MegaHZ = 5
) (
    input sys_clk,
    input _rst,
    input str,
    output busy,
    input [7:0] IRreg,
    input [7:0] data,
    output reg CS = 1'b1,
    output reg CLK = 1'b0,
    output reg Din = 1'b0
);

    // Slow SPI clock: ~50kHz for maximum reliability over wires
    // 5MHz / 100 = 50kHz
    reg [7:0] clk_cnt = 0;
    reg [5:0] bit_cnt = 0;
    reg [15:0] shift_reg = 0;
    reg [2:0] state = 0;

    localparam IDLE      = 3'd0;
    localparam SETUP_BIT = 3'd1;
    localparam CLK_HIGH  = 3'd2;
    localparam CLK_LOW   = 3'd3;
    localparam LATCH     = 3'd4;

    assign busy = (state != IDLE);

    always @(posedge sys_clk or negedge _rst) begin
        if (!_rst) begin
            state <= IDLE;
            CS <= 1'b1;
            CLK <= 1'b0;
            Din <= 1'b0;
            clk_cnt <= 0;
            bit_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    CS <= 1'b1;
                    CLK <= 1'b0;
                    if (str) begin
                        shift_reg <= {IRreg, data};
                        bit_cnt <= 16;
                        state <= SETUP_BIT;
                        clk_cnt <= 0;
                        CS <= 1'b0;
                    end
                end

                SETUP_BIT: begin
                    // Set Data well before Clock goes high
                    Din <= shift_reg[bit_cnt-1];
                    if (clk_cnt == 50) begin
                        clk_cnt <= 0;
                        state <= CLK_HIGH;
                        CLK <= 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                CLK_HIGH: begin
                    if (clk_cnt == 50) begin
                        clk_cnt <= 0;
                        CLK <= 1'b0;
                        if (bit_cnt == 1) begin
                            state <= LATCH;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                            state <= SETUP_BIT;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                LATCH: begin
                    // Hold CS low after last clock for setup time
                    if (clk_cnt == 50) begin
                        CS <= 1'b1; // Rising edge latches data
                        clk_cnt <= 0;
                        state <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule
