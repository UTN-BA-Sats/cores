"""Finite state machine (FSM) with i2c_master_oe and FIFO"""

import cocotb
import random

from cocotb.triggers import Timer
from cocotb.triggers import RisingEdge
from cocotb.triggers import FallingEdge
import cocotb.types

#VARIABLES GLOBALES
#------------------

#REGISTROS
#------------------------------------------------------------------------
none = ['0','0','0','0','0','0','0','0']
data = ['0','0','0','1','0','0','1','0']
data_decimal = ['0','1','1','1','0','0','0','0']
registers = [data,none,none,none,none,none,none,none,none,none,none,none,none,none,none,none,none,none,none,none,none,data_decimal,none]
#------------------------------------------------------------------------

#INDICES
#------------------------------------------------------------------------
index_check_addr=0
index_data = 0
index_registers=0
register_pointer=0
read_index=0
#------------------------------------------------------------------------

#FLAGS
#------------------------------------------------------------------------
gen_ack_nack=0
bit_RW='2'

flag_reading_register=0
error=0

scl_prev_value = '1'
sda_prev_value = '1'
start = 0
stop = 1
#------------------------------------------------------------------------

#OTRAS VARIABLES
#------------------------------------------------------------------------
REGISTER_POINTER_CONFIG_SLAVE = "00001001"        # 0x09
REGISTER_CONFIG_DATA_SLAVE = "00001000"           # 0x04
ADDR_VECTOR = "10011100"                          # 0x4e
data_write_vector = []
UART_MESSAGE = "10000110"#"11110010" y "01000000" # 97 para obtener los datos del sensor 0 y 105 para solo resetear la FSM 0            
UART_DIVIDER_NUMBER = 230                         # (Clock/Baudrate)
#------------------------------------------------------------------------

#ESTADOS I2C SLAVE
#------------------------------------------------------------------------
IDLE = 0
CHECK_ADDR = 1
ACK_NACK=2
WRITE=3                                           # Escribir en el registro
READ=4                                            # Leer el registro
WAIT_ACK_NACK=5
#------------------------------------------------------------------------

#VARIABLES UART
#------------------------------------------------------------------------
state = IDLE
clk = 0
uart_state = IDLE
uart_counter = UART_DIVIDER_NUMBER
uart_message_index = 0
CANT_PEDIDOS_INFO_SENSOR = 5                      # Cantidad de veces que se quiere pedir informacion
uart_contador_pedidos = CANT_PEDIDOS_INFO_SENSOR - 1
#------------------------------------------------------------------------

#ESTADOS UART
#------------------------------------------------------------------------
UART_START = 1
UART_SEND_MESSAGE=2
UART_STOP=3
UART_DIVIDER=4
#------------------------------------------------------------------------

async def clock(dut):
    global clk
    dut.i_clk.value = 0
    clk = 0
    while True:
        dut.i_clk.value = not dut.i_clk.value
        clk = dut.i_clk.value
        await Timer(19,'ns')

def i2c_slave(dut,scl,sda):
    global index_check_addr
    global gen_ack_nack
    global bit_RW
    global index_data
    global data_write_vector
    global register_pointer
    global error
    global ADDR_VECTOR 
    global index_registers
    global state     
    global registers
    global scl_prev_value
    global sda_prev_value
    global start
    global stop

    if(scl_prev_value=='1' and scl=='1' and sda=='1' and sda_prev_value=='0' and state!=READ): 
            start=0
            stop=1
            state = IDLE
    elif(scl_prev_value=='1' and scl=='1' and sda=='0' and sda_prev_value=='1' and state!=READ): 
            start=1
            stop=0
            state = CHECK_ADDR

            index_check_addr=0
            gen_ack_nack=0
            bit_RW='2'
            index_data = 0
            index_registers=-1
            data_write_vector = []
            error=0

    if(start==0 and stop==1):
        index_check_addr=0
        gen_ack_nack=0
        bit_RW='2'
        index_data = 0
        index_registers=-1
        data_write_vector = []
        error=0
    elif(not (scl=='1' and scl_prev_value=='0')):
        state=state                                                             #Accion redudante
    elif(state==CHECK_ADDR):

        if(index_check_addr<0): index_check_addr=index_check_addr+1             #Para cuando viene del estado WAIT_ACK_NACK y darle un ciclo de scl mas al slave
        elif(sda==ADDR_VECTOR[index_check_addr] and index_check_addr<7):
            index_check_addr=index_check_addr+1
        elif(sda!=ADDR_VECTOR[index_check_addr] and index_check_addr<7):
            error=1
            index_check_addr=index_check_addr+1
        elif(index_check_addr>=7):
            bit_RW = sda
            if(error): gen_ack_nack=2
            else: gen_ack_nack=1

            state=ACK_NACK

    elif(state==ACK_NACK):

        if(gen_ack_nack==1):
            dut.sda0.value=0

            if(bit_RW=='0'):
                index_data=7
                state=WRITE
            else:
                index_registers=0
                state=READ

        elif(gen_ack_nack==2):
            dut.sda0.value=1
            state=CHECK_ADDR
        elif(gen_ack_nack==3):
            dut.sda0.value=0
            index_data=7
            state=WRITE
        elif(gen_ack_nack==4):
            dut.sda0.value=0
            index_registers=0
            state=IDLE
        elif(gen_ack_nack==5):
            dut.sda0.value=0
            state=IDLE

            index_check_addr=-1
            gen_ack_nack=0
            bit_RW='2'
            index_data = 0
            index_registers=-1
            data_write_vector = []
            register_pointer=0
            error=0

        verification()

    elif(state==WRITE):
        if(index_data>=0):
            data_write_vector.append(sda)
            index_data=index_data-1
        
        if(gen_ack_nack!=3 and index_data<0):
            gen_ack_nack=3
            register_pointer=int("".join(data_write_vector),2)
            data_write_vector=[]
            state=ACK_NACK
        elif(index_data<0):
            registers[register_pointer] = data_write_vector
            state=ACK_NACK
            gen_ack_nack=5
    elif(state==READ):
        dut.sda0.value=int(registers[register_pointer][index_registers])
        index_registers=index_registers+1
        if(index_registers>7):
            gen_ack_nack=4 
            state=ACK_NACK

    scl_prev_value=scl
    sda_prev_value=sda

def verification():
    global index_check_addr
    global gen_ack_nack
    global bit_RW
    global index_data
    global data_write_vector
    global register_pointer
    global error
    global ADDR_VECTOR 
    global index_registers
    global state     
    global registers
    global scl_prev_value
    global sda_prev_value
    global start
    global stop

    if(gen_ack_nack==2):
        assert error, "Wrong ADDR slave"
    elif(gen_ack_nack==3):
        assert (register_pointer!=int(REGISTER_POINTER_CONFIG_SLAVE,2)), "Wrong register pointer"
    elif(gen_ack_nack==5):
        assert (registers[register_pointer]!=int(REGISTER_CONFIG_DATA_SLAVE,2)), "Wrong register information"

def uart_reader(dut):

    global uart_state
    global uart_counter
    global uart_message_index

    if(uart_state==UART_START):
        dut.i_rx.value = 0        #Start
        uart_state = UART_DIVIDER
        uart_counter = UART_DIVIDER_NUMBER
    elif(uart_state==UART_SEND_MESSAGE):
        dut.i_rx.value = int(UART_MESSAGE[uart_message_index],2)
        uart_message_index=uart_message_index+1

        uart_state = UART_DIVIDER
        uart_counter = UART_DIVIDER_NUMBER

    elif(uart_state==UART_DIVIDER):
        uart_counter=uart_counter-1
        if(uart_counter<=0):
            if(uart_message_index>=8):
                uart_message_index = 0
                uart_state = UART_STOP
            else:
                uart_state = UART_SEND_MESSAGE
    elif(uart_state==UART_STOP):
        dut.i_rx.value = 1        #Stop
        uart_state = IDLE
    

@cocotb.test()
async def test_FSM_I2C_FIFO_UART(dut):  

    global uart_state
    global uart_contador_pedidos

    scl = dut.scl0.value.binstr
    sda = dut.sda0.value.binstr
    clk_prev_value = dut.i_clk.value.binstr
    dut.i_rx.value = 1

    contador=150000    

    cocotb.start_soon(clock(dut))

    dut.i_rst.value = 1

    await Timer(30, 'us')

    dut.i_rst.value = 0

    while contador>0:

        scl = dut.scl0.value.binstr
        sda = dut.sda0.value.binstr

        await RisingEdge(dut.i_clk)

        i2c_slave(dut,scl,sda)

        if(contador<25000):
            uart_reader(dut)
        elif(contador==25000):
            uart_state=UART_START

        if(uart_contador_pedidos>0 and contador>=0 and contador < 5):
            uart_contador_pedidos=uart_contador_pedidos-1
            contador=50002

        contador = contador - 1