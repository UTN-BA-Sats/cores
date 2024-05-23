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
IGNORED_SRC_FOLDERS = ["__pycache__", "sim_build"]


DUT = "FIFO"
GENERICS = {"ADDR_LENGTH":4, "WORD_LENGTH": 4}
MAX_TEST_CYCLES = 2

@cocotb.test()
async def handshake_write_and_read(dut):
    test_data = 10
    clkTask = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clkTask.start())

    # Reset and initial values
    for i in range(5):
        await RisingEdge(dut.clk)

    dut.reset = 1
    dut.data_in_valid = 0
    dut.ready_out = 0
    
    await RisingEdge(dut.clk)
    
    dut.reset = 0

    for i in range(5):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    for i in range(10):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    # Data input
    dut.data_in = test_data
    dut.data_in_valid = 1

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert 0 == dut.ready_in

    dut.data_in_valid = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert 1 == dut.ready_in
    
    # Data output
    dut.ready_out = 1

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert 1 == dut.data_out_valid

    test_read = dut.data_out
    assert test_data == test_read

    dut.ready_out = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid

@cocotb.test()
async def multiple_writes_and_reads(dut):
    test_data = [12, 5, 8, 15, 2, 1, 4]
    clkTask = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clkTask.start())

    # Reset and initial values
    for i in range(5):
        await RisingEdge(dut.clk)

    dut.reset = 1
    dut.data_in_valid = 0
    dut.ready_out = 0
    
    await RisingEdge(dut.clk)
    
    dut.reset = 0

    for i in range(5):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    for i in range(10):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    # Data input
    for val in test_data:
        dut.data_in = val
        dut.data_in_valid = 1

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        assert 0 == dut.ready_in
        dut.data_in_valid = 0

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        assert 1 == dut.ready_in

    # Data output
    for expected_val in test_data:
        dut.ready_out = 1

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        assert 1 == dut.data_out_valid

        val = dut.data_out
        assert expected_val == val

        dut.ready_out = 0

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        assert 0 == dut.data_out_valid

@cocotb.test()
async def write_until_full(dut):
    # FIFO capacity = 2^ADDR_LENGTH - 1 = 15
    test_data = [12, 5, 8, 15, 2, 1, 4, 3, 6, 9, 7, 14, 11, 13, 10]
    last_data = 0
    clkTask = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clkTask.start())

    # Reset and initial values
    for i in range(5):
        await RisingEdge(dut.clk)

    dut.reset = 1
    dut.data_in_valid = 0
    dut.ready_out = 0
    
    await RisingEdge(dut.clk)
    
    dut.reset = 0

    for i in range(5):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    for i in range(10):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    write_count = 0

    # Data input
    for val in test_data:
        dut.data_in = val
        dut.data_in_valid = 1

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        assert 0 == dut.ready_in
        dut.data_in_valid = 0

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        write_count += 1

        if write_count < 15:
            assert 1 == dut.ready_in
        else:
            # FIFO full
            assert 0 == dut.ready_in

    # Try to write something and check that ready_in stays at 0
    dut.data_in = last_data
    dut.data_in_valid = 1

    for i in range(10):
        await RisingEdge(dut.clk)
        assert 0 == dut.ready_in

    dut.data_in_valid = 0

    # Read one data item
    dut.ready_out = 1

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert 1 == dut.data_out_valid
    out_val = dut.data_out
    assert test_data[0] == out_val

    dut.ready_out = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid

    # Now write the last item
    assert 1 == dut.ready_in

    dut.data_in_valid = 1
    dut.data_in = last_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    assert 0 == dut.ready_in
    dut.data_in_valid = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert 0 == dut.ready_in

    await RisingEdge(dut.clk)

    # FIFO full
    assert 0 == dut.ready_in

@cocotb.test()
async def several_writes_and_reads(dut):
    clkTask = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clkTask.start())

    # Reset and initial values
    for i in range(5):
        await RisingEdge(dut.clk)

    dut.reset = 1
    dut.data_in_valid = 0
    dut.ready_out = 0
    
    await RisingEdge(dut.clk)
    
    dut.reset = 0

    for i in range(5):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    for i in range(10):
        await RisingEdge(dut.clk)

    assert 0 == dut.data_out_valid
    assert 1 == dut.ready_in

    TESTS = 100
    for i in range(TESTS):
        test_data = random.sample(range(16), 5)

        # Write data
        for val in test_data:
            dut.data_in = val
            dut.data_in_valid = 1

            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)

            assert 0 == dut.ready_in
            dut.data_in_valid = 0

            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)

            assert 1 == dut.ready_in

        # Read back data
        for expected_val in test_data:
            dut.ready_out = 1

            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)

            assert 1 == dut.data_out_valid

            val = dut.data_out
            assert expected_val == val

            dut.ready_out = 0

            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)

            assert 0 == dut.data_out_valid

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
            py_module="test_fifo"
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
