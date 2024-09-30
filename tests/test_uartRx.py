import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly, First
import os
import sys
import subprocess
from pathlib import Path
import random

from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles

# do not change
COCOTB_HDL_TIMEUNIT = "1ns"
COCOTB_HDL_TIMEPRECISION = "1ps"
IGNORED_SRC_FOLDERS = ["__pycache__", "sim_build", "interface"]

CLK_PERIOD_NS = 50
DUT = "uart_rx"
BAUD = 115200
TEST_CYCLES = 5
RANDOM_BYTES = 6

async def generate_rx_clk(reset_signal, clk_signal, rx_pulse_signal, rx_sync_signal, counter_value:int):

    main_counter = 0
    rx_counter = 0
    clk_edge = RisingEdge(clk_signal)
    rst_edge = RisingEdge(reset_signal)
    rx_pulse_signal.value = 0
    
    while True:
        edge = await First(rst_edge, clk_edge)
        rx_pulse_signal.value = 0
        if (edge == rst_edge):
            main_counter = 0
            rx_counter = 0
        else:
            main_counter = (main_counter + 1) % counter_value
            if (main_counter == 0):
                rx_counter = (rx_counter + 1) % 16
                if (rx_counter >= 5 and rx_counter <= 7):
                    rx_pulse_signal.value = 1

            await ReadOnly()
            if (rx_sync_signal.value):
                main_counter = 0
                rx_counter = 0

"""Test for UART RX"""
@cocotb.test()
async def simple_test(dut):
 
    baudTickCount = int(1 / (BAUD * CLK_PERIOD_NS * 1e-9 * 16)) ## 1/16 baud tick time in nanoseconds
    assert baudTickCount > 0, "\n\
        Error Baud rate incompatible with system clock"
    
    dut.i_ready.value = 1
    dut.i_rxd.value = 1

    clk = Clock(dut.i_clk, CLK_PERIOD_NS, units='ns')
       
    cocotb.start_soon(clk.start())
    rx_clk_task = cocotb.start_soon(generate_rx_clk(dut.i_rst, dut.i_clk, dut.i_rxpulse, dut.o_rxsync, baudTickCount))
    await RisingEdge(dut.i_clk)

    #reset
    dut.i_rst.value = 1
    await Timer(random.randint(10, 20), units='ns')
    dut.i_rst.value = 0

    # Verificar que el dispositivo se resetee correctamente
    await RisingEdge(dut.i_clk)
    assert dut.i_rst.value == 0, "Error Device did not reset correctly"

    await RisingEdge(dut.i_clk)
    
    for x in range(TEST_CYCLES):
        # Setup random data
        data_byte = random.randint(0, 255) & 0xff
        dut.i_rxd.value = 0  # Start bit
        await ClockCycles(dut.i_clk, 16 * baudTickCount)

        for bit in range(8):
            dut.i_rxd.value = (data_byte >> bit) & 0x1
            await ClockCycles(dut.i_clk, 16 * baudTickCount)
        
        dut.i_rxd.value = 1  # Stop bit
        await ClockCycles(dut.i_clk, 16 * baudTickCount)

        # Wait for data to be valid
        while not dut.o_valid.value:
            await RisingEdge(dut.i_clk)
            await RisingEdge(dut.i_clk)
        
        # Verificar que los datos sean recibidos correctamente
        assert dut.o_data.value == data_byte, f"\n\
            Error Sent: {hex(data_byte)}, received: {hex(int(dut.o_data.value))}\n"
        
    rx_clk_task.kill()

def test_simple_dff_runner():
    
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sim_build_path = os.path.join(proj_path, "sim_build")

    # create directory for simulated waveform
    if not os.path.exists(sim_build_path):
        os.mkdir(sim_build_path)
    else:
        print("Not pre-creating sim_build directory because it exists")
    
    cmdfile_path = os.path.join(sim_build_path, "icarus_cmd.f")
    with open(cmdfile_path, "w") as cmdfile:
        cmdfile.write(f"+timescale+{COCOTB_HDL_TIMEUNIT}/{COCOTB_HDL_TIMEPRECISION})\n")

    wavever_path = os.path.join(sim_build_path, "cocotb_icarus_dump.v")
    with open(wavever_path, "w") as waveverfile:
        waveverfile.write("module cocotb_icarus_dump();\n")
        waveverfile.write("initial begin\n")
        waveverfile.write(f"$dumpfile(\"{sim_build_path}/waveform.vcd\");\n")
        waveverfile.write(f"$dumpvars(0, {DUT});\n")
        waveverfile.write("end\n")
        waveverfile.write("endmodule\n")
    
    
    sources = []

    #locate all verilog sources
    for path, subdirs, files in os.walk(proj_path):
        dirname = os.path.basename(os.path.normpath(path))
        if (dirname in IGNORED_SRC_FOLDERS):
            print(f"Ignoring folder {dirname}")
            continue
        for name in files:
            if name.endswith("uart_clkgen.v") or name.endswith("uart_rx.v") or name.endswith("uart_tx.v"):
                sourcePath = os.path.join(path, name)
                print(f"Adding source: {sourcePath}")
                sources.append(sourcePath)

    #include verilog to dump waveforms
    sources.append(wavever_path)
    
    runner = get_runner(sim)()
    runner.build(
        verilog_sources=sources,
        toplevel=DUT,
        extra_args=["-f", cmdfile_path],
    )

    try:
        runner.test(
        toplevel=DUT,
        py_module="test_uartRx"
        )
    
    except Exception as e:
        print(f"Error during simulation: {str(e)}")
        sys.exit(1)
     
    if len(sys.argv) > 1 and sys.argv[1] == "--wave":
        print("Calling gtkwave to view waveform...\n")
       
        wavefile = os.path.join(proj_path, "waveform.vcd")
        if (os.path.exists(wavefile)):
            prog = ["gtkwave", str(wavefile)]
            subprocess.run(prog)
       
    # Verificar que el programa se ejecute correctamente
    if len(sys.argv) == 1 or sys.argv[1] != "--wave":
        print("Simulation completed successfully.")
    else:
        print("Waveform visualization completed successfully.")
    
    # Verificar que las operaciones se ejecuten correctamente
    if os.path.exists(os.path.join(proj_path, "waveform.vcd")):
        print("Waveform file exists.")
    else:
        print("Error: Waveform file does not exist.")    

if __name__ == "__main__":
    test_simple_dff_runner()