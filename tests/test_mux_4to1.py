"""Codificador con prioridad

Multiplexor de una entrada y cuatro salidas. La entrada i_Sel selecciona sobre que salida
se escribe la entrada

"""
import cocotb
import random

from cocotb.triggers import Timer

MAX_ITERATIONS = 10

def verification(dut):
    if(dut.i_Sel.value == 0 and (dut.o_I0.value == dut.i_E.value)): return True
    elif(dut.i_Sel.value == 1 and (dut.o_I1.value == dut.i_E.value)): return True
    elif(dut.i_Sel.value == 2 and (dut.o_I2.value == dut.i_E.value)): return True
    elif(dut.i_Sel.value == 3 and (dut.o_I3.value == dut.i_E.value)): return True
    else: return False

@cocotb.test()
async def test_mux_4to1_deterministic(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    iterNumberSel = 4
    iterNumberInput = 16

    dut.i_E.value = 0
    dut.i_Sel.value = 0

    for i in range(iterNumberSel):

        dut.i_Sel.value = i

        for j in range(iterNumberInput):

            dut.i_E.value = j

            await Timer(1, 'ns')

            assert verification(dut),f"\
                Error! failed random test\n\
                i_Sel = {dut.i_Sel.value}, i_E = {dut.i_E.value}, o_I0 = {dut.o_I0.value},o_I1 = {dut.o_I1.value},o_I2 = {dut.o_I2.value},o_I3 = {dut.o_I3.value}"


@cocotb.test()
async def test_mux_4to1_random(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    iterNumber = 5

    for i in range(iterNumber):

        dut.i_E.value = random.randint(0,15)
        dut.i_Sel.value = random.randint(0,3)

        await Timer(1, 'ns')

        assert verification(dut),f"\
            Error! failed random test\n\
            i_Sel = {dut.i_Sel.value}, i_E = {dut.i_E.value}, o_I0 = {dut.o_I0.value},o_I1 = {dut.o_I1.value},o_I2 = {dut.o_I2.value},o_I3 = {dut.o_I3.value}"