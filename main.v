module main #(
    parameter integer BLINK_MAX = 12_500_000,
    parameter integer SEC_MAX = 5_000_000
) (
    input clk,       // 25MHz
    input n_reset,   // Active low reset
    output user_led,
    output spi_clk,
    output spi_mosi,
    input spi_miso,
    output spi_ss
);

    // Manual Clock Divider for Logic: 25MHz / 5 = 5MHz
    reg [2:0] div_cnt;
    reg clk_5m;
    always @(posedge clk or negedge n_reset) begin
        if (!n_reset) begin
            div_cnt <= 0;
            clk_5m <= 0;
        end else begin
            if (div_cnt == 4) div_cnt <= 0;
            else div_cnt <= div_cnt + 1;
            
            if (div_cnt < 2) clk_5m <= 1;
            else clk_5m <= 0;
        end
    end

    // Visible Heartbeat
    reg [24:0] blink_cnt;
    reg led_reg;
    always @(posedge clk or negedge n_reset) begin
        if (!n_reset) begin
            blink_cnt <= 0;
            led_reg <= 0;
        end else begin
            if (blink_cnt >= BLINK_MAX - 1) begin
                blink_cnt <= 0;
                led_reg <= ~led_reg;
            end else begin
                blink_cnt <= blink_cnt + 1;
            end
        end
    end
    assign user_led = led_reg;

    usage_MAX7219 #(
        .SEC_MAX(SEC_MAX)
    ) u_basic (
        .sys_clk(clk_5m),
        ._rst(n_reset),
        ._str(1'b0),
        .Din(spi_mosi),
        .CS(spi_ss),
        .CLK(spi_clk),
        .shutdown(1'b1)
    );

endmodule
