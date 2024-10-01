#
#   Cobotb test bench for sign expander module
#
import cocotb
import random

from cocotb.triggers import Timer
from cocotb.clock    import Clock
from cocotb.triggers import ClockCycles

MAX_ITERATIONS = 16

@cocotb.test() #Modificador que indica que lo inferior es un test de cocotb
async def test_sign_expander(dut):

    cocotb.start_soon(Clock(dut.clk, 1, units="us").start())  # Create and start the clock
    dut.i_A.value = 0

    for i in range(MAX_ITERATIONS):

        await Timer(3, 'us')

        assert bin(dut.o_Z.value)[-4:] == bin(dut.i_A.value)[-4:], f"\
            Error! failed random test\n\
            i_A = {dut.i_A.value}, o_Z = {dut.o_Z.value}"
        
        dut.i_A.value += 0b1
        