import os
import subprocess
from pathlib import Path
import argparse
import random

import cocotb
from cocotb.runner import get_runner
from cocotb.triggers import Timer

DUT = "ej_4"


@cocotb.test()
async def mux_4to1_test(dut):
    for piE in range(16):
        for piSel in range(4):
            dut.piSel.value = piSel
            dut.piE.value = piE

            await Timer(2, units='ns')

            assert dut.piSel.value != 4, "Error! Failed basic and test."

            list = [dut.poI0.value, dut.poI1.value, dut.poI2.value, dut.poI3.value]

            assert list[int(dut.piSel.value)] == dut.piE.value and list.count(0) >= 3, "Error! Failed basic and test."


@cocotb.test()
async def mux_4to1_test_random(dut):
    for E in range(10):
        dut.piSel.value = random.randint(0, 3)
        dut.piE.value = random.randint(0, 15)

        await Timer(2, units='ns')
        assert dut.piSel.value != 4, "Error! Failed basic and test."

        list = [dut.poI0.value, dut.poI1.value, dut.poI2.value, dut.poI3.value]

        assert list[int(dut.piSel.value)] == dut.piE.value and list.count(0) >= 3, "Error! Failed basic and test."


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
                    py_module=os.path.basename(__file__)[:-3],
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
