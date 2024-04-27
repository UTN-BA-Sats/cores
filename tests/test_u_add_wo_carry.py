#
#   cocotb testbench for unsigned add without carry module
#
import cocotb
import random

from cocotb.triggers import Timer
from cocotb.clock    import Clock
from cocotb.triggers import ClockCycles

MAX_ITERATIONS = 10

#Realiza la suma bit a bit sin el carry
def bitwise_sum(a, b):
    result = 0
    carry = 0
    for i in range(4):
        sum_bit = (a & (1 << i)) ^ (b & (1 << i)) ^ carry
        carry = (a & (1 << i)) & (b & (1 << i))
        result |= (sum_bit << i)
        print("restulado:" + str(bin(result)))
    return result


@cocotb.test() #Modificador que indica que lo inferior es un test de cocotb
async def test_u_add_wo_carry(dut):

    cocotb.start_soon(Clock(dut.clk, 1, units="us").start())  # Create and start the clock

    for i in range(MAX_ITERATIONS):

        dut.i_A.value   = random.randint(0,15)
        dut.i_B.value   = random.randint(0,15)

        await Timer(3, 'us')

        #Para la comparacion tomo los 3 bits menos significativos que deberán ser iguales si se realiza o no carry
        assert str(dut.o_Z.value)[-3:] == str(bin(dut.i_A.value + dut.i_B.value).zfill(5))[-3:], f"\
            Error! failed random test\n\
            a = {dut.i_A.value}, b = {dut.i_B.value}, z = {dut.o_Z.value}, obtenido = {str(bin(dut.i_A.value + dut.i_B.value).zfill(5))[-3:]}"
        
        