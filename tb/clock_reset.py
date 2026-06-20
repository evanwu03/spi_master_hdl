
import cocotb
from cocotb.clock import Clock 
from cocotb.triggers import Timer
from cocotb.triggers import RisingEdge


def start_clock(clk, period_ns=10): 
    return cocotb.start_soon(Clock(clk, period_ns, unit="ns").start())


async def reset_dut(clk, rst, active_low=True, cycles = 2): 
    rst.value = 0 if active_low else 1

    for _ in range(cycles): 
        await RisingEdge(clk)


    rst.value = 1 if active_low else 0
    await RisingEdge(clk)

    await Timer(1, unit="ns")