import argparse
import logging
import os
import subprocess

from cocotb.runner import get_runner
from tempfile import TemporaryDirectory


# Build and test configs
HDL_LANGUAGE = 'verilog'
VERILOG_SIM_DEFAULT = 'icarus'
VERILOG_GPI_INTERFACES = ["vpi"]
TESTS_DIRECTORY = 'tests'
MODULES_DIRECTORY = 'rtl'
ICARUS_CFG_FILE = 'icarus.cf'

# Verilog directives to dump the test result in a vcd waveform file
VERILOG_DUMP_CONFIG_FILE = 'verilog_dump.v'
MODULE_PLACEHOLDER = 'REPLACE_WITH_MODULE_NAME'
WAVEFORM_FILE = 'waveform.vcd'

sim = os.getenv('SIM', VERILOG_SIM_DEFAULT)
logger = logging.getLogger(name='run_tests')


def get_testable_modules():
    """ Get all testable modules

        Return a list of tuples with (module, module_path, test_path)
    """
    modules = {}

    for dirpath, dirnames, filenames in os.walk(MODULES_DIRECTORY):
        for file in filenames:
            if file.endswith('.v'):
                modules[file.removesuffix('.v')] = os.path.join(dirpath, file)

    testable_modules = []

    for dirpath, dirnames, filenames in os.walk(TESTS_DIRECTORY):
        for file in filenames:
            if file.startswith('test_') and file.endswith('.py'):
                module = file.removeprefix('test_').removesuffix('.py')
                module_path = modules.get(module)
                if module_path:
                    test_path = os.path.join(dirpath, file)
                    testable_modules.append((module, module_path, test_path))

    return testable_modules


def config_waveform_dump(tmp_dir, module):
    """ Generates a temporary config file to dump a waveform file

        Returns a the tmp configuration file path
    """

    with open(VERILOG_DUMP_CONFIG_FILE, 'r') as file:
        filedata = file.read()

    filedata = filedata.replace(MODULE_PLACEHOLDER, module)

    tmp_conf = os.path.join(tmp_dir, VERILOG_DUMP_CONFIG_FILE)

    with open(tmp_conf, 'w+') as file:
        file.write(filedata)

    return tmp_conf


def test_cocotb(dut, waves=False):

    runner = get_runner(sim)

    testeable_modules = get_testable_modules()

    if dut:
        modules = [mod for mod in testeable_modules if mod[0] == dut]

        if modules == []:
            logger.error(f'Missing DUT {dut}')
            return 1
    else:
        modules = testeable_modules

    for module, module_path, test_path in modules:

        with TemporaryDirectory() as tmp_dir:

            module_dir = module_path.removesuffix(f'{module}.v')

            runner.build(
                verilog_sources=[module_path, config_waveform_dump(tmp_dir, module)],
                hdl_toplevel=module,
                build_dir=module_dir,
                build_args=["-f", os.path.abspath(ICARUS_CFG_FILE)],
            )

            runner.test(
                hdl_toplevel_lang=HDL_LANGUAGE,
                hdl_toplevel=module,
                test_module=f"test_{module}",
                gpi_interfaces=VERILOG_GPI_INTERFACES,
                build_dir=module_dir,
                test_dir=module_dir,
                plusargs=['-f', os.path.abspath(ICARUS_CFG_FILE)],
                waves=True,
            )

        if dut and waves:
            waveform = os.path.join(module_dir, WAVEFORM_FILE)
            subprocess.run(['gtkwave', waveform])


def parse_args():
    p = argparse.ArgumentParser(prog='tun_tests.py',
                                description='Helper to run tests')

    p.add_argument('--dut', help='Run test for one DUT')

    dut = p.add_argument_group('dut')
    dut.add_argument('-w', '--waves', action='store_true', help='Open waveforms')

    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()

    test_cocotb(args.dut, args.waves)
