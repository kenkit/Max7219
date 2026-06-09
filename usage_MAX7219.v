module usage_MAX7219 #(
    parameter integer SEC_MAX = 5_000_000 // Cycles per second at 5MHz
) (
    input sys_clk,
    input _rst,
    input _str,    // Start trigger (Active Low)
    output Din,
    output CS,
    output CLK,
    input shutdown
);

// MAX7219 register indexing
reg [3:0]IRreg_cnt = 4'hC; // Start sequence at shutdown register
reg [7:0]spi_data = 8'h00;
reg [3:0]digit_cnt = 4'd0;
wire busy;
reg str_internal = 0; // Internal trigger signal

// Instantiate MAX7219 Driver
MAX7219#(.Freq_MegaHZ(5))
		 U0(.sys_clk(sys_clk), ._rst(_rst), .str(str_internal), .busy(busy), .IRreg({4'b0000,IRreg_cnt}), .data(spi_data), .CS(CS), .CLK(CLK), .Din(Din));

// 1 Second Timer: Tracks time for digit update
reg [22:0]one_sec_timer = 'd0;
reg update_trigger = 1'b1; // Triggers a burst update

always @(posedge sys_clk or negedge _rst) begin
    if (!_rst) begin
        one_sec_timer <= 0;
        digit_cnt <= 0;
        update_trigger <= 1'b1;
    end else begin
        if (one_sec_timer >= SEC_MAX - 1) begin
            one_sec_timer <= 0;
            if (digit_cnt == 9) digit_cnt <= 0;
            else digit_cnt <= digit_cnt + 1;
            update_trigger <= 1'b1;
        end else begin
            one_sec_timer <= one_sec_timer + 1;
            // Stop trigger once the sequence completes
            if (IRreg_cnt == 4'hF && !busy && !str_internal) update_trigger <= 1'b0;
        end
    end
end

// Font Definition: 64-bit map for 8x8 matrix digits 0-9
function [63:0] get_digit;
    input [3:0] d;
    case (d)
        0: get_digit = 64'h3C6666666666663C;
        1: get_digit = 64'h7E18181818183818;
        2: get_digit = 64'h7E6030180C06663C;
        3: get_digit = 64'h3C6606063C06663C;
        4: get_digit = 64'h0C0C0C7E6C3C1C0C;
        5: get_digit = 64'h3C6606067E60667E;
        6: get_digit = 64'h3C6666667E60663C;
        7: get_digit = 64'h18181818180C067E;
        8: get_digit = 64'h3C66663C3C66663C;
        9: get_digit = 64'h3C66063E6666663C;
        default: get_digit = 64'h0000000000000000;
    endcase
endfunction

wire [63:0] bitmap = get_digit(digit_cnt);

// Update Sequence Controller:
// Drives the MAX7219 through the initialization and row-data sequence.
always @(posedge sys_clk or negedge _rst) begin
    if (!_rst) begin
        IRreg_cnt <= 4'hC;
        str_internal <= 1'b0;
    end else begin
        // Trigger SPI start
        if (update_trigger && !busy && !str_internal) begin
            str_internal <= 1'b1;
        end else if (busy) begin
            str_internal <= 1'b0;
        end
        
        // Progress to next register after transmission finishes
        if (!busy && !str_internal && update_trigger) begin
            case (IRreg_cnt)
                4'hC: IRreg_cnt <= 4'h9;
                4'h9: IRreg_cnt <= 4'hA;
                4'hA: IRreg_cnt <= 4'hB;
                4'hB: IRreg_cnt <= 4'hF;
                4'hF: IRreg_cnt <= 4'h1;
                4'h1: IRreg_cnt <= 4'h2;
                4'h2: IRreg_cnt <= 4'h3;
                4'h3: IRreg_cnt <= 4'h4;
                4'h4: IRreg_cnt <= 4'h5;
                4'h5: IRreg_cnt <= 4'h6;
                4'h6: IRreg_cnt <= 4'h7;
                4'h7: IRreg_cnt <= 4'h8;
                4'h8: IRreg_cnt <= 4'hC; // Loop
                default: IRreg_cnt <= 4'hC;
            endcase
        end
    end
end

// Data Mapper: Unified pipeline for control commands and row data.
// This block acts as a lookup table to select the correct 8-bit data
// packet (either a slice of the 64-bit bitmap or a control command)
// based on the register address currently being processed.
always @(*) begin
    case(IRreg_cnt)
        //--- Row Data Section: Maps bitmap slices to MAX7219 digit registers ---
        4'h1: spi_data = bitmap[7:0];    // Reg 0x01: Row 1
        4'h2: spi_data = bitmap[15:8];   // Reg 0x02: Row 2
        4'h3: spi_data = bitmap[23:16];  // Reg 0x03: Row 3
        4'h4: spi_data = bitmap[31:24];  // Reg 0x04: Row 4
        4'h5: spi_data = bitmap[39:32];  // Reg 0x05: Row 5
        4'h6: spi_data = bitmap[47:40];  // Reg 0x06: Row 6
        4'h7: spi_data = bitmap[55:48];  // Reg 0x07: Row 7
        4'h8: spi_data = bitmap[63:56];  // Reg 0x08: Row 8

        //--- Control Register Section: Configuration commands ---
        4'h9: spi_data = 8'h00; // Decode mode: 0x09
        4'hA: spi_data = 8'h01; // Intensity:   0x0A
        4'hB: spi_data = 8'h07; // Scan limit:  0x0B
        4'hC: spi_data = 8'h01; // Shutdown:    0x0C
        4'hF: spi_data = 8'h00; // Test mode:   0x0F
        default: spi_data = 8'h00;
    endcase
end

endmodule
