"""Comparador de numero NO signados

Comparador de números de 8 bits (parameter=N, definido en este archivo y en 
el archivo de verilog como N) con tres salidas: Mayor, Menos e Igual.

"""

import cocotb
import random

from cocotb.triggers import Timer

MAX_ITERATIONS = 10
N = 8

def verification(dut):
    if((dut.i_A.value == dut.i_B.value) and (dut.o_Igual.value == 1) and (dut.o_Mayor.value == 0) and (dut.o_Menor.value == 0)): return True
    elif((int(str(dut.i_A.value),2) > int(str(dut.i_B.value),2)) and (dut.o_Igual.value == 0) and (dut.o_Mayor.value == 1) and (dut.o_Menor.value == 0)): return True
    elif((int(str(dut.i_A.value),2) < int(str(dut.i_B.value),2)) and (dut.o_Igual.value == 0) and (dut.o_Mayor.value == 0) and (dut.o_Menor.value == 1)): return True
    else: return False

@cocotb.test()
async def test_comparator_deterministic(dut):

    iterNumber = pow(2,N)

    dut.i_A.value = 0
    dut.i_B.value = 0

    for i in range(iterNumber):

        dut.i_B.value = i

        for j in range(iterNumber):

            dut.i_A.value = j

            await Timer(1, 'ns')

            assert verification(dut),f"\
                Error! failed random test\n\
                o_Mayor = {dut.o_Mayor.value}, o_Menor = {dut.o_Menor.value}, o_Igual = {dut.o_Igual.value} , i_A = {dut.i_A.value}, i_B = {dut.i_B.value}"


@cocotb.test()
async def test_comparator_random(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    iterNumber = 20
    maxNumber = pow(2,N) - 1

    for i in range(iterNumber):

        dut.i_A.value = random.randint(0,maxNumber)
        dut.i_B.value = random.randint(0,maxNumber)
        await Timer(1, 'ns')

        assert verification(dut),f"\
            Error! failed random test\n\
            o_Mayor = {dut.o_Mayor.value}, o_Menor = {dut.o_Menor.value}, o_Igual = {dut.o_Igual.value} , i_A = {dut.i_A.value}, i_B = {dut.i_B.value}"