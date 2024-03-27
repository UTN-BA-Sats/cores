"""Sumador/Restador sin carryOut ni carryIn

Sumador y restador de 4 bits(determinado por el parametro N en este archivo y
en el archivo de verilog). Considerar que este modulo no contempla la situación de overflow

"""
import cocotb
import random

from cocotb.triggers import Timer
from cocotb.binary import BinaryValue, BinaryRepresentation

MAX_ITERATIONS = 10
N = 4

def verification(dut):

    a = BinaryValue(value=str(dut.i_A.value), bigEndian=False, binaryRepresentation=BinaryRepresentation.TWOS_COMPLEMENT)
    b = BinaryValue(value=str(dut.i_B.value), bigEndian=False, binaryRepresentation=BinaryRepresentation.TWOS_COMPLEMENT)
    o = BinaryValue(value=str(dut.i_Op.value), bigEndian=False, binaryRepresentation=BinaryRepresentation.UNSIGNED)
    z = BinaryValue(value=str(dut.o_Z.value), bigEndian=False, binaryRepresentation=BinaryRepresentation.TWOS_COMPLEMENT)

    if((o.integer == 0) and (a.integer + b.integer == z.integer)): return True
    elif((o.integer == 1) and (a.integer - b.integer == z.integer)): return True
    else: 
        #IGNORE OVERFLOW
        if((a.integer + b.integer) > 7 or (a.integer + b.integer) < -8): return True
        elif((a.integer - b.integer) > 7 or (a.integer - b.integer) < -8): return True
        else: return False

@cocotb.test()
async def test_s_addsub_wo_carry_deterministic(dut):

    maxNumber = pow(2,N)
    iterNumber = maxNumber

    dut.i_A.value = 0
    dut.i_B.value = 0

    dut.i_Op.value = 0

    for z in range(2):
        
        dut.i_Op.value = z

        for i in range(iterNumber):

            dut.i_B.value = i

            for j in range(iterNumber):

                dut.i_A.value = j

                await Timer(1, 'ns')

                assert verification(dut),f"\
                    Error! failed random test\n\
                    o_Z = {dut.o_Z.value}, i_A = {dut.i_A.value}, i_B = {dut.i_B.value} , i_Op = {dut.i_Op.value}"

@cocotb.test()
async def test_s_addsub_wo_carry_random(dut):

    iterNumber = random.randint(1,MAX_ITERATIONS)
    maxNumber = pow(2,N)

    for i in range(iterNumber):

        dut.i_A.value = random.randint(0,((maxNumber)-1))
        dut.i_B.value = random.randint(0,((maxNumber)-1))

        dut.i_Op.value = random.randint(0,1)

        await Timer(1, 'ns')

        assert verification(dut),f"\
            Error! failed random test\n\
            o_Z = {dut.o_Z.value}, i_A = {dut.i_A.value}, i_B = {dut.i_B.value} , i_Op = {dut.i_Op.value}"