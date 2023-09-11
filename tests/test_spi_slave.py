import cocotb

from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotbext.spi import SpiMaster, SpiSignals, SpiConfig

clock_period = 10  # us


def get_spi_master(dut):
    spi_signals = SpiSignals(
        sclk=dut.spi_sclk,
        mosi=dut.spi_mosi,
        miso=dut.spi_miso,
        cs=dut.spi_cs_n,
    )

    spi_config = SpiConfig(
        word_width=8,  # number of bits in a SPI transaction
        sclk_freq=10000,  # clock rate in Hz
        cpol=False,  # clock idle polarity
        cpha=True,  # clock phase (CPHA=True means data sampled on second edge)
        msb_first=True,  # the order that bits are clocked onto the wire
        data_output_idle=1,  # the idle value of the MOSI or MISO line
        ignore_rx_value=None,  # MISO value that should be ignored when received
    )

    spi_master = SpiMaster(spi_signals, spi_config)

    return spi_master


def init_clock(dut):
    clock = Clock(dut.clk, clock_period, units="us")
    cocotb.fork(clock.start())


async def init_spi(dut):
    dut.rst.value = 1
    dut.tx_tvalid.value = 0
    dut.tx_tdata.value = 0
    dut.rx_tready.value = 0
    await Timer(3 * clock_period, 'us')
    dut.rst.value = 0


@cocotb.test()
async def test_01_slave_receives(dut):
    init_clock(dut)
    await init_spi(dut)

    data = 0x61
    spi_master = get_spi_master(dut)
    await spi_master.write([data])

    assert dut.rx_tvalid.value == 1
    assert dut.rx_tdata.value == data

    dut.rx_tready.value = 1
    await RisingEdge(dut.clk)
    dut.rx_tready.value = 0
    await RisingEdge(dut.clk)
    # Review if we need this extra clock. It means that rx_tready is registered
    await RisingEdge(dut.clk)

    assert dut.rx_tvalid.value == 0


@cocotb.test()
async def test_02_slave_transmit(dut):
    init_clock(dut)
    await init_spi(dut)

    data = 0x61

    assert dut.tx_tready.value == 1

    dut.tx_tdata.value = data
    dut.tx_tvalid.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    # Review if we need this extra clock. It means that rx_tready is registered
    await RisingEdge(dut.clk)

    assert dut.tx_tready.value == 0

    spi_master = get_spi_master(dut)
    await spi_master.write([0x10])
    await spi_master.wait()
    read_bytes = await spi_master.read()

    assert int(read_bytes.hex(), 16) == 0x61
    await Timer(3 * clock_period, 'us')
