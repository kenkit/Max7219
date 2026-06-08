`timescale 1ns / 1ps

module testbench;

    reg clk = 0;
    reg n_reset = 0;
    wire user_led;
    wire spi_clk;
    wire spi_mosi;
    wire spi_ss;

    // Use parameters for fast simulation
    localparam integer BLINK_MAX = 50;
    localparam integer SEC_MAX = 500;

    main #(
        .BLINK_MAX(BLINK_MAX),
        .SEC_MAX(SEC_MAX)
    ) dut (
        .clk(clk),
        .n_reset(n_reset),
        .user_led(user_led),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(1'b0),
        .spi_ss(spi_ss)
    );

    // 25MHz clock (40ns period)
    always #20 clk = ~clk;

    integer i;
    reg expected_led = 0;
    integer spi_active_count = 0;

    initial begin
        $dumpvars(0, testbench);

        $display("Starting simulation...");
        
        // Reset sequence
        n_reset = 0;
        #100;
        @(posedge clk);
        n_reset = 1;
        $display("Reset released.");

        // Verification Loop
        // Sample on negative edge to avoid race conditions with positive edge updates
        for (i = 0; i < 10000; i = i + 1) begin
            @(negedge clk);

            // Update expected LED based on BLINK_MAX
            if ((i + 1) % BLINK_MAX == 0) begin
                expected_led = ~expected_led;
            end

            // 1. Verify Heartbeat LED
            if (user_led !== expected_led) begin
                $display("ERROR at cycle %0d: user_led = %b, expected = %b", i, user_led, expected_led);
                if (!`APIO_SIM) $fatal(1, "LED heartbeat mismatch");
            end

            // 2. Track SPI Activity
            if (spi_ss == 1'b0) begin
                spi_active_count = spi_active_count + 1;
            end
        end

        // 3. Final Verification
        if (spi_active_count == 0) begin
            $display("ERROR: No SPI activity detected (spi_ss stayed HIGH)");
            if (!`APIO_SIM) $fatal(1, "SPI communication failure");
        end else begin
            $display("SPI activity confirmed: CS was LOW for %0d cycles", spi_active_count);
        end

        $display("Simulation SUCCESS.");
        $finish;
    end

endmodule
