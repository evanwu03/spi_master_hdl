# Author: Evan Wu
# Date of Revision: 6/14/2026


import os
from pathlib import Path
import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

from clock_reset import reset_dut
from clock_reset import start_clock

def setup_dut(dut):
    dut.i_rst_n.value = 0
    dut.i_start.value = 0
    dut.i_miso.value = 0

async def drive_mcp3201_sample(dut, sample: int):
    """Drive one MCP3201-style 12-bit sample on MISO."""
    bits = [(sample >> i) & 1 for i in range(11, -1, -1)]

    # Wait for CS active low: transaction started
    while int(dut.o_cs_n.value) != 0:
        await RisingEdge(dut.i_clk)

    # Burn MCP3201 startup/sample/null timing:
    # falling #1, falling #2 means we've passed:
    # rising, falling, rising, falling
    await FallingEdge(dut.o_sclk)
    await FallingEdge(dut.o_sclk)

    # Drive B11..B0.
    # ADC changes DOUT on falling edge; master samples on rising edge.
    for idx, bit in enumerate(bits):
        dut.i_miso.value = bit
        await RisingEdge(dut.o_sclk)

        if idx != len(bits) - 1:
            await FallingEdge(dut.o_sclk)

    # Wait until transaction releases CS high again
    while int(dut.o_cs_n.value) != 1:
        await RisingEdge(dut.i_clk)


@cocotb.test()
async def test_single_adc_sample(dut):
    """Quick test: start one MCP3201-style SPI transaction and receive one 12-bit sample."""

    clk = dut.i_clk
    rst = dut.i_rst_n

    # 100 MHz clock = 10 ns period
    start_clock(clk=clk, period_ns=10)

    setup_dut(dut)
    await reset_dut(clk=clk, rst=rst, active_low=True, cycles=2)


    #sample = 0b1010_1100_0011
    sample = 0xAC4

    # Start sampling
    dut.i_start.value = 1
    await Timer(10, unit="ns")
    dut.i_start.value = 0

    await drive_mcp3201_sample(dut, sample)

    # Wait for valid pulse
    while int(dut.o_valid.value) != 1:
        await RisingEdge(dut.i_clk)

    valid = int (dut.o_valid.value)
    received_sample = int(dut.o_sample.value)
    

    assert valid == 1, "o_valid did not pulse after 12-bit sample"
    assert received_sample == sample, (
        f"Expected sample 0x{sample:03X}, got 0x{int(dut.o_sample.value):03X}"
    )

    dut._log.info(f"Received sample correctly: 0x{int(dut.o_sample.value):03X}")



@cocotb.test()
async def test_five_consecutive_adc_samples(dut):
    """Hold i_start high and receive 5 consecutive 12-bit samples."""

    samples = [
        0x001,
        0x123,
        0xABC,
        0x555,
        0xF0A,
    ]


    clk = dut.i_clk
    rst = dut.i_rst_n

    # 100 MHz clock = 10 ns period
    start_clock(clk=clk, period_ns=10)

    setup_dut(dut)
    await reset_dut(clk=clk, rst=rst, active_low=True, cycles=2)

    # Hold start high to request repeated transactions
    dut.i_start.value = 1

    received = []

    for expected in samples:
        # Start ADC response task for this transaction
        await drive_mcp3201_sample(dut, expected)

        # Wait for valid pulse
        while int(dut.o_valid.value) != 1:
            await RisingEdge(dut.i_clk)

        received_sample = int(dut.o_sample.value)
        received.append(received_sample)

        assert received_sample == expected, (
            f"Expected 0x{expected:03X}, got 0x{received_sample:03X}"
        )

        dut._log.info(f"Received sample: 0x{received_sample:03X}")

    # Now stop requesting new samples
    dut.i_start.value = 0

    # Give it a few clocks and make sure it settles idle
    for _ in range(10):
        await RisingEdge(dut.i_clk)

    assert int(dut.o_cs_n.value) == 1, "CS should be high after stopping"
    assert int(dut.o_sclk.value) == 0, "SCLK should idle low after stopping"

    dut._log.info(f"Received all samples: {[hex(x) for x in received]}")


def test_spi_master_runner():
    
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [ 
        proj_path / "rtl" / "spi_pkg.sv",
        proj_path / "rtl" / "sclk_tick_gen.sv",
        proj_path / "rtl" / "spi_master.sv",
        ]

    runner = get_runner(sim)

    parameters = {

    }

    runner.build(
        sources=sources,
        hdl_toplevel="spi_master",
        parameters=parameters,
        build_dir="sim_build/spi_master",
        always=True,
        clean=True
        
    )

    runner.test(
        hdl_toplevel="spi_master",
        test_module="spi",
        parameters=parameters,
        build_dir="sim_build/spi_master",        
    )

if __name__ == "__main__":
    test_spi_master_runner()
