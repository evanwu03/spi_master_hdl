// Author: Evan Wu
// Date: 6/13/2026

`default_nettype none
`timescale 1ns/1ps

/* verilator lint_off WIDTHEXPAND */

module sclk_tick_gen #(
    parameter int CLK_HZ  = 100_000_000,
    parameter int SCLK_HZ = 800_000
) (
    input  wire logic i_clk,
    input  wire logic i_rst_n,

    input  wire logic i_en,

    output logic o_tick
);

    localparam int HALF_PERIOD_COUNT = CLK_HZ / (2 * SCLK_HZ);
    localparam int DIV_CNT_W = (HALF_PERIOD_COUNT <= 1) ? 1 : $clog2(HALF_PERIOD_COUNT);

    logic [DIV_CNT_W-1:0] div_count;

    /*
    initial begin
        if (SCLK_HZ <= 0)
            $error("SCLK_HZ must be greater than 0");

        if (CLK_HZ < 2*SCLK_HZ)
            $error("CLK_HZ must be at least 2*SCLK_HZ");

        if (HALF_PERIOD_COUNT < 1)
            $error("HALF_PERIOD_COUNT must be at least 1");

        if ((CLK_HZ % (2*SCLK_HZ)) != 0)
            $warning("CLK_HZ is not an integer multiple of 2*SCLK_HZ; SCLK will be truncated");
    end
    */

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            div_count <= '0;
            o_tick    <= 1'b0;
        end else begin
            o_tick <= 1'b0;

            if (i_en) begin
                if (div_count == HALF_PERIOD_COUNT-1) begin
                    div_count <= '0;
                    o_tick    <= 1'b1;
                end else begin
                    div_count <= div_count + 1'b1;
                end
            end else begin
                div_count <= '0;
            end
        end
    end

endmodule
