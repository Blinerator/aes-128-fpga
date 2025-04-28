# © 2025 Ilya Cable <ilya.cable1@gmail.com>
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer
from common.common import *
 

class TB():
    def __init__(self, dut):
        self.dut = dut

    async def reset(self):
        await RisingEdge(self.dut.clk)
        self.dut.reset_enc.value = 1
        self.dut.reset_dec.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.reset_enc.value = 0
        self.dut.reset_dec.value = 0
        await RisingEdge(self.dut.clk)
        
    async def init_encryption(self, init_vec, key, data):
        self.dut.init_vec_enc.value = init_vec
        self.dut.key_enc.value = key
        self.dut.plaintext_enc.value = data

    async def start_encryption(self):
        self.dut.start_enc.value = 1
        await sync(self.dut, 1)
        self.dut.start_enc.value = 0

    async def get_cipherblock(self):
        await RisingEdge(self.dut.done_enc)
        return self.dut.cipherblock_enc.value
    
    async def init_decryption(self, init_vec, key, data):
        self.dut.init_vec_dec.value = init_vec
        self.dut.key_dec.value = key
        self.dut.cipherblock_dec.value = data

    async def start_decryption(self):
        self.dut.start_dec.value = 1
        await sync(self.dut, 1)
        self.dut.start_dec.value = 0

    async def get_plaintext(self):
        await RisingEdge(self.dut.done_dec)
        return self.dut.plaintext_dec.value