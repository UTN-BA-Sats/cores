"""Codificador con prioridad

Codificador que saca en valor binario el número del bit activo más significativo. Además, cuenta
con un indicador para diferenciar la situcación donde la entrada es cero y cuando la entrada es uno
            
            ____
i_I3------>|    |
i_I2------>|    |---->o_C (Número del bit activo)
i_I1------>|    |---->o_G (Indicador de i_IO=0 o i_I0=1)
i_I0------>|____|

"""

import cocotb
import random

from cocotb.triggers import Timer

MAX_ITERATIONS = 10

def verification(dut):
    if((dut.i_I3.value == 1) and (dut.o_C.value == 3)): return True
    elif((dut.i_I2.value == 1) and (dut.o_C.value == 2)): return True
    elif((dut.i_I1.value == 1) and (dut.o_C.value == 1)): return True
    elif((dut.i_I0.value == 1) and (dut.o_C.value == 0)): return True
    elif((dut.o_C.value == 0) and (dut.o_G.value == 1)): return True
    else: return False

@cocotb.test()
async def test_cod_w_prio_deterministic(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    iterNumber = 16

    for i in range(iterNumber):

        a = bin(i)[2:].zfill(4)

        dut.i_I0.value = int(a[3])
        dut.i_I1.value = int(a[2])
        dut.i_I2.value = int(a[1])
        dut.i_I3.value = int(a[0])

        await Timer(1, 'ns')

        assert verification(dut),f"\
            Error! failed random test\n\
            o_C = {dut.o_C.value}, o_G = {dut.o_G.value}, i_I = {a}"
    

@cocotb.test()
async def test_cod_w_prio_random(dut):

    #iterNumber = random.randint(1,MAX_ITERATIONS)
    iterNumber = 15

    a = []

    for i in range(iterNumber):

        dut.i_I0.value = random.randint(0,1)
        dut.i_I1.value = random.randint(0,1)
        dut.i_I2.value = random.randint(0,1)
        dut.i_I3.value = random.randint(0,1)

        a.append(dut.i_I3.value)
        a.append(dut.i_I2.value)
        a.append(dut.i_I1.value)
        a.append(dut.i_I0.value)

        await Timer(1, 'ns')

        assert verification(dut),f"\
            Error! failed random test\n\
            o_C = {dut.o_C.value}, o_G = {dut.o_G.value}, i_I = {a}"