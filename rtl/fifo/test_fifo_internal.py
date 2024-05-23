# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

import os
import sys
import subprocess
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import Timer
from cocotb.triggers import RisingEdge
from cocotb.triggers import ClockCycles
from cocotb.triggers import ReadOnly
from cocotb.triggers import ReadWrite
from cocotb.triggers import NextTimeStep

#do not change
COCOTB_HDL_TIMEUNIT = "1ns"
COCOTB_HDL_TIMEPRECISION = "1ps"
IGNORED_SRC_FOLDERS = ["__pycache__", "sim_build", "interface"]


DUT = "FIFO_internal"
GENERICS = {"ADDR_LENGTH":4, "WORD_LENGTH": 4}
MAX_TEST_CYCLES = 2

async def store(dut, clkTask, val):
    assert 0 == dut.full
    dut.data_in = val
    dut.write_en = 1
    await RisingEdge(dut.clk)
    dut.write_en = 0

async def readOutput(dut, clkTask):
    await RisingEdge(dut.clk)
    return dut.data_out

async def clear_memory(dut):
    dut.data_in = 0
    dut.reset = 1
    await RisingEdge(dut.clk)
    dut.reset = 0
    dut.read_en = 0
    dut.write_en = 1
    for i in range(15):
        await RisingEdge(dut.clk)
    dut.write_en = 0


@cocotb.test()
async def full_and_empty(dut):
    test_data = [5, 3, 11, 8, 15, 4, 1, 9, 10, 12, 13, 2, 0, 6, 7]#, 14]
    clkTask = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clkTask.start())

    await Timer(random.randint(5, 50), units="ns")
    dut.reset = 1
    dut.read_en = 0
    dut.write_en = 0
    dut.data_in = 0
    await Timer(random.randint(1, 10), units="ns")
    dut.reset = 0

    assert 0 == dut.full
    assert 1 == dut.empty

    for i in range(10):
        await RisingEdge(dut.clk)

    for val in test_data[0:len(test_data)]:
        assert 0 == dut.full
        await store(dut, clkTask, val)
        # assert 0 == dut.empty

    await RisingEdge(dut.clk)
    assert 1 == dut.full

    dut.read_en = 1

    for expected_val in test_data:
        assert 0 == dut.empty
        val = await readOutput(dut, clkTask)
        await Timer(1, units="ns")
        assert val == expected_val

    await RisingEdge(dut.clk)
    assert 1 == dut.empty

@cocotb.test()
async def store_and_read(dut):
    test_data = [1, 3, 11, 8, 15, 4, 1, 9, 10, 12, 13, 2, 0, 6, 7, 14]

    clkTask = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clkTask.start())

    await clear_memory(dut)

    await Timer(random.randint(5, 50), units="ns")
    dut.reset = 1
    dut.read_en = 0
    dut.write_en = 0
    dut.data_in = 0
    await Timer(random.randint(1, 10), units="ns")
    dut.reset = 0

    for i in range(10):
        await RisingEdge(dut.clk)

    dut.read_en = 1

    for val in test_data:
        # First rising edge => data stored
        await store(dut, clkTask, val)
        # Second rising edge => data copied to output register
        await RisingEdge(dut.clk)
        # Third rising edge => data read from output register
        read_val = await readOutput(dut, clkTask)
        assert val == read_val

@cocotb.test()
async def wrap_around(dut):
    test_data1 = [3, 5, 7, 9, 11, 13, 15, 2, 4, 6]
    test_data2 = [11, 12, 13, 14, 15, 4, 5, 6, 7, 8]

    clkTask = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clkTask.start())

    await clear_memory(dut)

    await Timer(random.randint(5, 50), units="ns")
    dut.reset = 1
    dut.write_en = 0
    dut.read_en = 0
    dut.data_in = 0
    await Timer(random.randint(1, 10), units="ns")
    dut.reset = 0

    for i in range(10):
        await RisingEdge(dut.clk)

    # Store 10 values
    for val in test_data1:
        await store(dut, clkTask, val)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.read_en = 1

    # Read back the stored values
    for expected_val in test_data1:
        assert 0 == dut.empty
        val = await readOutput(dut, clkTask)
        await Timer(1, units="ns")
        assert expected_val == val

    dut.read_en = 0

    # Store 10 more values
    for val in test_data2:
        await store(dut, clkTask, val)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.read_en = 1

    # Read back the stored values, FIFO pointers should wrap around after 15
    for expected_val in test_data2:
        assert 0 == dut.empty
        val = await readOutput(dut, clkTask)
        await Timer(1, units="ns")
        print(expected_val, "==", int(val), "?")
        assert expected_val == val

def test_simple_dff_runner():

    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent

    sources = []

    # create directory for simulated waveform
    try:
        os.mkdir(os.path.join(proj_path, "sim_build"))
    except FileExistsError:
        print("Not pre-creating sim_build directory because it exists")

    # create command file to establish iverilog timesteps
    # cocotb defaults to timescale 1ns, timeprecision 1ps
    cmdfile_path = os.path.join(proj_path, "sim_build", "icarus_cmd.f")
    cmdfile = open(cmdfile_path, "w")
    cmdfile.write(f"+timescale+{COCOTB_HDL_TIMEUNIT}/{COCOTB_HDL_TIMEPRECISION})\n")
    cmdfile.close()

    #create extra verilog file to enable waveforms
    #same as done in Makefile.icarus from cocotb repo
    wavever_path = os.path.join(proj_path, "sim_build", "cocotb_icarus_dump.v")
    waveverfile = open(wavever_path, "w")
    waveverfile.write("module cocotb_icarus_dump();\n")
    waveverfile.write("initial begin\n")
    waveverfile.write(f"$dumpfile(\"{proj_path}/sim_build/waveform.vcd\");\n")
    waveverfile.write(f"$dumpvars(0, {DUT});\n")
    waveverfile.write("end\n")
    waveverfile.write("endmodule\n")
    waveverfile.close()

    #locate all verilog sources
    for path, subdirs, files in os.walk(proj_path):
        dirname = os.path.basename(os.path.normpath(path))
        if (dirname in IGNORED_SRC_FOLDERS):
            print(f"Ignoring folder {dirname}")
            continue
        for name in files:
            if name.endswith(".v"):
                sourcePath = os.path.join(path, name)
                print("Adding source: " + sourcePath)
                sources.append(os.path.relpath(sourcePath, proj_path))

    #include verilog to dump waveforms
    sources.append(os.path.join("./", "sim_build", "cocotb_icarus_dump.v"))

    runner = get_runner(sim)()
    runner.build(
        verilog_sources=sources,
        toplevel=DUT,
        parameters=GENERICS,
        extra_args=["-f", cmdfile_path],
    )

    try:
        runner.test(
            toplevel=DUT, 
            py_module="test_fifo_internal"
            )
    except:
        pass
    
    if (sys.argv[1] == "--wave"):
        print("Calling gtkwave to view waveform...\n")
        wavefile = os.path.join(proj_path, "sim_build", "waveform.vcd")
        if (os.path.exists(wavefile)):
            prog = ["gtkwave", str(os.path.relpath(wavefile, proj_path))]
            subprocess.run(prog)
    


if __name__ == "__main__":
    test_simple_dff_runner()