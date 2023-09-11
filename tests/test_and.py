import os
import subprocess
from pathlib import Path
import argparse
import random

import cocotb
from cocotb.runner import get_runner
from cocotb.triggers import Timer

DUT = "and"

# puertos
# piA, piB : in STD_LOGIC;
# poZ : out STD_LOGIC


@cocotb.test
async def and_test(dut):
    for i in range(2):
        for j in range(2):
            dut.piA.value = i
            dut.piB.value = j

            await Timer(2, units='ns')
            assert dut.poZ.value == (i and j), "Error! Failed basic and test."


@cocotb.test
async def and_random_test(dut):
    for i in range(10):
        a = random.randint(0, 1)
        b = random.randint(0, 1)
        dut.piA.value = a
        dut.piB.value = b

        await Timer(2, units='ns')

        z = dut.poZ.value

        assert (a and b) == z, f"\
            Error! failed random test\n\
            a = {a}, b = {b}, z = {z}"

        print(f"values: a = {a}, b = {b}, z = {z}\n")


def test_simple_dff_runner():

    sim = os.getenv("SIM", "ghdl")

    proj_path = Path(__file__).resolve().parent

    vhdl_sources = []

    for path, subdirs, files in os.walk(proj_path):
        for name in files:
            if name.endswith((".vhd", ".vhdl")):
                sourcePath = os.path.join(path, name)
                print("Adding source: " + sourcePath)
                vhdl_sources.append(os.path.relpath(sourcePath, proj_path))

    runner = get_runner(sim)()
    runner.build(
        vhdl_sources=vhdl_sources, toplevel=DUT
    )

    try:
        runner.test(toplevel=DUT,
                    py_module="test_uartTx",
                    extra_args=["--wave=waveform.ghw", "--stop-delta=1000000"])
    except Exception as e:
        print(f"Exception {str(e)}")
        pass


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("-w", "--wave", action="store_true", help="Open gtk-wave on finish")
    parser.add_argument("-vw", "--view-wave", action="store_true", help="Open gtkwave, does not simulate again")

    args = parser.parse_args()

    if not args.view_wave:
        test_simple_dff_runner()
    if args.wave or args.view_wave:
        print("Calling gtkwave to view waveform...\n")
        proj_path = Path(__file__).resolve().parent
        wavefile = os.path.join(proj_path, "sim_build", "waveform.ghw")
        if (os.path.exists(wavefile)):
            prog = ["gtkwave", str(os.path.relpath(wavefile, proj_path))]
            subprocess.run(prog)
