"""Conversor binario a gray

Testbench de un conversor de codigo binario a gray.
Entradas de 8 bits (N) que proviene del archivo en verilog (parameter)

"""
import cocotb
import random

from cocotb.triggers import Timer

MAX_ITERATIONS = 10
N = 8

def flip_num(my_nu):
    return '1' if(my_nu == '0') else '0'

def gray_to_binary(gray):

    binary_code = ""
    binary_code += gray[0]
    for i in range(1,len(gray)):
        if(gray[i] == '0'):
            binary_code += binary_code[i-1]
        else:
            binary_code += flip_num(binary_code[i-1])
    
    return int(binary_code,2)

def verification(dut):
    if(dut.o_Bin.value == gray_to_binary(str(dut.i_Gray.value))): return True
    else: return False

@cocotb.test()
async def test_bin2gray_deterministic(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    maxNumber = pow(2,N) - 1
    iterNumber = maxNumber + 1
    dut.i_Gray.value = 0

    for i in range(iterNumber):

        await Timer(1, 'ns')

        assert verification(dut),f"\
            Error! failed random test\n\
            o_Bin = {dut.o_Bin.value}, i_Gray = {dut.i_Gray.value}"
        
        if(i < 255): dut.i_Gray.value = dut.i_Gray.value + 1

@cocotb.test()
async def test_bin2gray_random(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    iterNumber = 10
    maxNumber = pow(2,N) - 1

    for i in range(iterNumber):

        dut.i_Gray.value = random.randint(0,maxNumber)

        await Timer(1, 'ns')

        assert verification(dut),f"\
            Error! failed random test\n\
            o_Bin = {dut.o_Bin.value}, i_Gray = {dut.i_Gray.value}"