
`timescale 1ns/1ps
`default_nettype none

module spi_master_top #(
    parameter int DATA_W = 12,
    parameter int CLK_HZ  = 100_000_000,
    parameter int SCLK_HZ = 800_000
    
)(
    input  wire logic i_clk,
    input  wire logic i_rst_n,
    input  wire logic i_start,

    input  wire logic i_miso,
    output logic o_sclk,
    output logic o_cs_n
);

logic [DATA_W-1:0] o_sample;
logic        o_valid;


// Add button logic to toggle the start
spi_master #(
    .DATA_W(DATA_W),
    .CLK_HZ(CLK_HZ),
    .SCLK_HZ(SCLK_HZ)
) spi_master_inst (
    .i_clk   (i_clk),
    .i_rst_n (i_rst_n),
    .i_start (i_start),
    .i_miso  (i_miso),
    .o_sclk  (o_sclk),
    .o_cs_n  (o_cs_n),
    .o_sample  (o_sample),
    .o_valid (o_valid)
);



endmodule : spi_master_top
