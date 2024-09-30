# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

import os
import sys
import subprocess
from pathlib import Path
import random
import argparse

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer

# Añadir el directorio principal a sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from drv.streamDrv import StreamDrv
from drv.uartDrv import UartDrv

#do not change
COCOTB_HDL_TIMEUNIT = "1ns"
COCOTB_HDL_TIMEPRECISION = "1ps"
IGNORED_SRC_FOLDERS = ["__pycache__", "sim_build", "interface"]

CLK_PERIOD_NS = 50
DUT = "uart_tx"
BAUD = 115200
TEST_CYCLES = 5
RANDOM_BYTES = 6

async def tx_pulse_gen(dut, baudTickCount):
    while True:
        await ClockCycles(dut.i_clk, (baudTickCount + 1) * 15)
        dut.i_txpulse.value = 1
        await RisingEdge(dut.i_clk)
        dut.i_txpulse.value = 0
        await ClockCycles(dut.i_clk, baudTickCount)


@cocotb.test()
async def simple_test(dut):


    baudTickCount = int(1 / (BAUD * CLK_PERIOD_NS * 1e-9 * 16)) ## 1/16 baud tick time in nanoseconds
    assert baudTickCount > 0, "\n\
        Error Baud rate incompatible with system clock"
    
    stream_in = StreamDrv(dut.i_data, dut.i_valid, dut.o_ready, True)
    uart_drv = UartDrv(BAUD, None, dut.o_txd)


    clk = Clock(dut.i_clk, CLK_PERIOD_NS, units='ns')

    pulse_gen = tx_pulse_gen(dut, baudTickCount)

    cocotb.start_soon(clk.start())
    cocotb.start_soon(pulse_gen)
    await RisingEdge(dut.i_clk)

    #reset
    dut.i_rst.value = 1
    await Timer(random.randint(1, 20), units='ns')
    dut.i_rst.value = 0

    await RisingEdge(dut.i_clk)

    for x in range(TEST_CYCLES):
        #setup random data
        data_bytes = random.randbytes(RANDOM_BYTES)
        for byte in data_bytes:
            await stream_in.write(byte)
            recv = await uart_drv.receive(dut)
            if (recv == -1):
                print("Error UART Framing error on reception!")
            else:
                assert recv == byte, f"\n\
                Error Sent: {hex(byte)}, received: {hex(recv)}\n"

def test_simple_dff_runner():

    sim = os.getenv("SIM", "icarus")
    
    proj_path = Path(__file__).resolve().parent.parent
    
    sources = []

    # create directory for simulated waveform
    try:
        os.mkdir(os.path.join(proj_path, "sim_build"))
    except FileExistsError:
        print("Not pre-creating sim_build directory because it exists")

    # create command file to establish iverilog timesteps
    # cocotb defaults to timescale 1ns, timeprecision 1ps
    cmdfile_path = os.path.join(proj_path, "sim_build", "icarus_cmd.f")
    with open(cmdfile_path, "w") as cmdfile:
        cmdfile.write(f"+timescale+{COCOTB_HDL_TIMEUNIT}/{COCOTB_HDL_TIMEPRECISION})\n")

    #create extra verilog file to enable waveforms
    #same as done in Makefile.icarus from cocotb repo
    wavever_path = os.path.join(proj_path, "sim_build", "cocotb_icarus_dump.v")
    with open(wavever_path, "w") as waveverfile:
        waveverfile.write("module cocotb_icarus_dump();\n")
        waveverfile.write("initial begin\n")
        waveverfile.write(f"$dumpfile(\"{proj_path}/sim_build/waveform.vcd\");\n")
        waveverfile.write(f"$dumpvars(0, {DUT});\n")
        waveverfile.write("end\n")
        waveverfile.write("endmodule\n")

    #locate all verilog sources
    for path, subdirs, files in os.walk(proj_path):
        dirname = os.path.basename(os.path.normpath(path))
        if (dirname in IGNORED_SRC_FOLDERS):
            print(f"Ignoring folder {dirname}")
            continue
        for name in files:
            if name.endswith(".v") and ("uart_clkgen" in name or "uart_rx" in name or "uart_tx" in name):
                sourcePath = os.path.join(path, name)
                print("Adding source: " + sourcePath)
                sources.append(sourcePath)

    #include verilog to dump waveforms
    sources.append(os.path.join(proj_path, "sim_build", "cocotb_icarus_dump.v"))
    
    runner = get_runner(sim)()
    runner.build(
        verilog_sources=sources,
        toplevel=DUT,
        extra_args=["-f", cmdfile_path],
    )

    try:
        runner.test(
            toplevel=DUT,
            py_module="test_uartTx"
            )
    except Exception as e:
        print(f"Test failed: {e}")

    if len(sys.argv) > 1 and sys.argv[1] == "--wave":
        print("Calling gtkwave to view waveform...\n")
        wavefile = os.path.join(proj_path, "sim_build", "waveform.vcd")
        if (os.path.exists(wavefile)):
            prog = ["gtkwave", str(os.path.relpath(wavefile, proj_path))]
            subprocess.run(prog)


if __name__ == "__main__":
    test_simple_dff_runner()
