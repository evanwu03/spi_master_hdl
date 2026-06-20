// Description: custom SPI master module for reading ADC samples from a MCP3201 ADC chip
// Author: Evan Wu
// Date: 6/13/2026

/* verilator lint_off WIDTHEXPAND */

`timescale 1ns/1ps
`default_nettype none

import spi_pkg::*;

module spi_master #(
    parameter int DATA_W = 12, // Same width as ADC resolution 
    parameter int CLK_HZ = 100_000_000, // 100 MHz global clock
    parameter int SCLK_HZ = 800_000

) (
    input wire logic i_clk,
    input wire logic i_rst_n,

    input wire logic  i_start, // Transaction request, can be wired to a physical button or another module 
    input wire logic  i_miso,
    output logic o_sclk,
    output logic o_cs_n,

    output logic [DATA_W-1:0] o_sample,
    output logic o_valid
); 


`ifdef SIMULATION
initial begin
    if (SCLK_HZ < 10_000) $error("MCP3201 SCLK_HZ must be >= 10kHz to maintain conversion accuracy");
end
`endif


spi_pkg::spi_state_e state;
spi_pkg::spi_state_e next_state;


// Tick generator for o_sclk
logic sclk_tick;
logic sclk_rising_edge;
logic sclk_falling_edge;
logic sclk_en;

logic [1:0] start_toggle_count;
logic [3:0] rx_bit_count;

logic [DATA_W-1:0] rx_shift;


sclk_tick_gen #(
    .CLK_HZ(CLK_HZ),
    .SCLK_HZ(SCLK_HZ)
) u_sclk_tick_gen (
    .i_clk   (i_clk),
    .i_rst_n (i_rst_n),
    .i_en    (sclk_en),
    .o_tick  (sclk_tick)
);



// Generates SCLK
always_ff @(posedge i_clk) begin
    if (!i_rst_n) begin
        o_sclk <= 1'b0;
    end else begin
        if (!sclk_en)
            o_sclk <= 1'b0;
        else if (sclk_tick)
            o_sclk <= ~o_sclk;
    end
end


assign sclk_rising_edge = sclk_tick && ~o_sclk;
assign sclk_falling_edge = sclk_tick && o_sclk;


// Counts number of toggles
always_ff @(posedge i_clk) begin
    if (!i_rst_n) begin
        start_toggle_count <= '0;
    end else begin
        if (state == SPI_IDLE) begin
            start_toggle_count <= '0;
        end else if (state == SPI_START && (sclk_rising_edge || sclk_falling_edge)) begin
            start_toggle_count <= start_toggle_count + 1'b1;
        end
    end
end


// States:
// IDLE - No data is to be received from SPI slave
// START - CS is asserted low. ADC samples input starting on first rising SCLK edge.
//         Sampling ends on the falling edge of the second SCLK.
//         A null bit is output after the sample phase.
// DATA - Shift N bits from i_miso. MCP3201 changes DOUT on falling SCLK edges,
//        so this master should sample i_miso on rising SCLK edges.
//        Deassert CS after the Nth data bit has been sampled. CS must be pulled high between conversions


// Handle state transition
always_ff @(posedge i_clk) begin

    if (!i_rst_n) begin
        state <= SPI_IDLE;
    end else begin
        state <= next_state;
    end
end


// Output generation and next state
always_comb begin 

    // Default next state assignment
    next_state = state;

    o_cs_n = 1'b1;
    sclk_en = 1'b0;

    case (state)

    SPI_IDLE: begin
        
        o_cs_n = 1'b1;;
        sclk_en  = 1'b0; // SCLK Idles low by default (SPI mode 0,0) In future this can be configured

        if (i_start) begin
            next_state = SPI_START;
        end else begin
            next_state = SPI_IDLE;
        end

    end
    SPI_START: begin
        
        o_cs_n = 1'b0;
        sclk_en = 1'b1;

         // transition after 3 SCLK toggles:
        // rising _> falling -> rising -> falling = 1.5 SCLK periods from first rising edge
        if (sclk_falling_edge && start_toggle_count == 2'd3) begin
            next_state = SPI_DATA;
        end 
            
    end

    SPI_DATA: begin

        o_cs_n = 1'b0;
        sclk_en = 1'b1;

        // A full sample has been counted
        if (sclk_rising_edge && rx_bit_count == DATA_W - 1) begin
           next_state = SPI_IDLE; 
        end

    end        
    default: next_state = SPI_IDLE; // FALLBACK to default state
    
    endcase

end


// Present State RX Datapath
always_ff @(posedge i_clk) begin
    if(!i_rst_n) begin
        //rx_shift <= '0;
        rx_bit_count <= '0;
        //o_sample <= '0;
        o_valid <= 1'b0;
    end else begin
        
        o_valid <= 1'b0;

        if (state == SPI_IDLE) begin
            //rx_shift <= '0;
            rx_bit_count <= '0;
        end 
        // Sample incoming data on rising edge of SCLK and shift it
        else if (state == SPI_DATA && sclk_rising_edge) begin
            
            rx_shift <= {rx_shift[DATA_W-2:0], i_miso};

            if (rx_bit_count == DATA_W-1) begin
                o_sample <= {rx_shift[DATA_W-2:0], i_miso};
                o_valid <= 1'b1;
                rx_bit_count <= '0;
            end else begin
                rx_bit_count <= rx_bit_count + 1'b1;
            end
        end
    end
end



`ifdef FORMAL

logic f_past_valid;

initial f_past_valid = 1'b0;
always_ff @(posedge i_clk) begin
    f_past_valid <= 1'b1;
end


// Property 1: Every design should start in the reset state
always_comb begin
    if(!f_past_valid)
        assume(!i_rst_n);
end

// If SCLK was disabled last cycle, then SCLK must be low now.
always_ff @(posedge i_clk) begin
    if (i_rst_n && f_past_valid && $past(i_rst_n)) begin
        if (!$past(sclk_en)) begin
            a_sclk_idle_low_when_disabled: assert(o_sclk == 1'b0);
        end
    end
end

// Property 3: CS must idle HIGH in the IDLE state
always_ff @(posedge i_clk) begin
    if (i_rst_n && state == SPI_IDLE) begin
        assert(o_cs_n);
    end
end

// Property 4: CS must be asserted LOW when not in IDLE state
always_ff @(posedge i_clk) begin
    if (i_rst_n && state != SPI_IDLE) begin
       assert(!o_cs_n); 
    end
end

// Property 5: DATA can only be entered from START on the 4th START edge
always_ff @(posedge i_clk) begin
    if (i_rst_n && state == SPI_START) begin
        if (next_state == SPI_DATA)
            assert(sclk_falling_edge && start_toggle_count == 2'd3);
    end
end
// Property 6: If we are in START and a tick occurs, SCLK must toggle.
always_ff @(posedge i_clk) begin
    if (i_rst_n && $past(i_rst_n)) begin
        if ($past(state == SPI_START && sclk_en && sclk_tick)) begin
            a_sclk_toggles_on_start_tick: assert (o_sclk == !$past(o_sclk));
        end
    end
end

// Property 7: Transition to DATA start must happen on a falling edge after the START period
always_ff @(posedge i_clk) begin
    if(i_rst_n && $past(i_rst_n)) begin
        if (state == SPI_START && sclk_falling_edge && start_toggle_count == 2'd3) begin
            a_enter_data_only_on_falling_edge: assert(next_state == SPI_DATA);
        end    
    end
end


// Property 8: Leave DATA only when final bit has been sampled
always_ff @(posedge i_clk) begin
    if (i_rst_n && f_past_valid) begin
        if (state == SPI_DATA && next_state == SPI_IDLE) begin
            a_leave_data_only_after_last_bit: assert (
                sclk_rising_edge && rx_bit_count == DATA_W-1
            );
        end
    end
end

// Property 9: If the final bit is sampled, we must leave DATA
always_ff @(posedge i_clk) begin
    if (i_rst_n && f_past_valid) begin
        if (state == SPI_DATA && sclk_rising_edge && rx_bit_count == DATA_W-1) begin
            a_final_bit_causes_idle: assert (next_state == SPI_IDLE);
        end
    end
end

// Property 10: If valid is high, it must be because the previous cycle sampled the final bit.
always_ff @(posedge i_clk) begin
    if (i_rst_n && $past(i_rst_n)) begin
        a_valid_only_after_last_bit: assert (
            !o_valid ||
            $past(state == SPI_DATA && sclk_rising_edge && rx_bit_count == DATA_W-1)
        );
    end
end


// Property 11: FSM is always in a valid state
always_ff @(posedge i_clk) begin
    if (i_rst_n) begin
        a_known_state: assert (
            state == SPI_IDLE || 
            state == SPI_START ||
            state == SPI_DATA
        );
    end
end

// Cover statements, is every known state reachable?
always_ff @(posedge i_clk) begin
    if (i_rst_n && f_past_valid) begin
        c_reach_start: cover (state == SPI_START);
        c_reach_data:  cover (state == SPI_DATA);
        c_reach_idle:  cover (state == SPI_IDLE);
        c_valid_seen:  cover (o_valid);
    end
end

`endif 


endmodule 