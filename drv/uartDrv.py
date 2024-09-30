
import cocotb
from cocotb.triggers import Timer
from cocotb.triggers import FallingEdge

class UartDrv:

    def __init__(self, baud, tx_sig, rx_sig) -> None:
        self.setBaudrate(baud)
        self.tx_sig = tx_sig
        self.rx_sig = rx_sig

    def setBaudrate(self, baud) -> None:
        self.baud = baud
        self.bit_period = int(1 / (baud * 1e-9))
        self.half_bit_period = int(1 / (baud * 1e-9 * 2))

    async def send(self, byte) -> None:
        await self._transmit_data(byte)

    async def receive(self, dut) -> int:
        return await self._receive_data(dut)

    async def _transmit_data(self, byte) -> None:
        databuf = "0" + bin(byte)[2:] + "1"
        for char in databuf:
            self.tx_sig = 1 if (char == "1") else 0
            await Timer(self.bit_period, units='ns')
        
    async def _receive_data(self, dut) -> int:
        databuf = ""
        await FallingEdge(self.rx_sig)
        await Timer(self.half_bit_period, units='ns')
        #dut.s_dut.value = 1
        databuf += "1" if (self.rx_sig.value == 1) else "0"
        for x in range(9):
            await Timer(self.bit_period, units='ns')
            databuf += "1" if (self.rx_sig.value == 1) else "0"
        #dut.s_dut.value = 0
        if (databuf[0] != "0" or databuf[-1] != "1") :
            return -1
        else:
            return int(databuf[1:9], 2)




