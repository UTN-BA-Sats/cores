"""Verilog And (Vand)

Testbench de una compuerta AND escrita en verilog
con entradas que varían cada un microsegundo

"""

import cocotb
import random

from cocotb.triggers import Timer

MAX_ITERATIONS = 10

@cocotb.test()
async def test_deterministic_Vand(dut):

    dut.i_a.value = 0
    dut.i_b.value = 0

    await Timer(1, 'us')
    
    assert dut.o_z.value == (dut.i_a.value and dut.i_b.value), f"\
        Error! failed random test\n\
        i_a = {dut.i_a.value}, i_b = {dut.i_b.value}, o_z = {dut.o_z.value}"
    
    dut.i_a.value = 0
    dut.i_b.value = 1

    await Timer(1, 'us')
    
    assert dut.o_z.value == (dut.i_a.value and dut.i_b.value), f"\
        Error! failed random test\n\
        i_a = {dut.i_a.value}, i_b = {dut.i_b.value}, o_z = {dut.o_z.value}"
    
    dut.i_a.value = 1
    dut.i_b.value = 0

    await Timer(1, 'us')
    
    assert dut.o_z.value == (dut.i_a.value and dut.i_b.value), f"\
        Error! failed random test\n\
        i_a = {dut.i_a.value}, i_b = {dut.i_b.value}, o_z = {dut.o_z.value}"
    
    dut.i_a.value = 1
    dut.i_b.value = 1

    await Timer(1, 'us')
    
    assert dut.o_z.value == (dut.i_a.value and dut.i_b.value), f"\
        Error! failed random test\n\
        i_a = {dut.i_a.value}, i_b = {dut.i_b.value}, o_z = {dut.o_z.value}"

@cocotb.test()
async def test_random_Vand(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    iterNumber = 4

    for i in range(iterNumber):

        dut.i_a.value = random.randint(0,1)
        dut.i_b.value = random.randint(0,1)

        await Timer(1, 'ns')
        
        assert dut.o_z.value == (dut.i_a.value and dut.i_b.value), f"\
            Error! failed random test\n\
            i_a = {dut.i_a.value}, i_b = {dut.i_b.value}, o_z = {dut.o_z.value}"