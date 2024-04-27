#
#   cocotb testbench for xor and not module
#
import cocotb
import random

from cocotb.triggers import Timer
from cocotb.clock    import Clock
from cocotb.triggers import ClockCycles

MAX_ITERATIONS = 10

@cocotb.test() #Modificador que indica que lo inferior es un test de cocotb
async def test_xor_and_not(dut):

    cocotb.start_soon(Clock(dut.clk, 1, units="us").start())  # Create and start the clock

    for i in range(MAX_ITERATIONS):

        await ClockCycles(dut.clk, 1)  # Wait for a clock cycle

        dut.a.value   = random.randint(0,1)
        dut.b.value   = random.randint(0,1)

        await Timer(3, 'us')
        
        assert dut.z.value == (~int(dut.a.value) ^ ~int(dut.b.value)), f"\
            Error! failed random test\n\
            a = {dut.a.value}, b = {dut.b.value}, z = {dut.z.value}"