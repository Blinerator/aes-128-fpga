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
    
    ### ENCRYPTION ###    
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
        await sync(self.dut, 1)
        return int(self.dut.cipherblock_enc.value)
    
    async def dut_encode(self, init_vec:int, key:int, plaintext:bytes|str):
        """Automatically pads plaintext with pkcs7 bytes up to AES block size"""
        # Convert data and pad if necessary
        if isinstance(plaintext, str):
            plaintext = plaintext.encode('utf-8')
            plaintext = pad(plaintext, AES.block_size, style = 'pkcs7')
        elif not isinstance(plaintext, bytes):
            raise ValueError("Plaintext must be bytes or str")

        await self.init_encryption(init_vec, key, int_f_b(plaintext[0:16]))
        await self.start_encryption()
        output = byte(await self.get_cipherblock())
        data_blocks = round(len(plaintext)/16)
        for i in range(1, data_blocks):
            self.dut.plaintext_enc.value = int_f_b(plaintext[i*16:(i+1)*16])
            await self.start_encryption()
            output += byte(await self.get_cipherblock())
        return plaintext, output

    ### DECRYPTION ###
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
        await sync(self.dut, 1)
        return int(self.dut.plaintext_dec.value)
    
    async def dut_decode(self, init_vec:int, key:int, cipherblock:bytes|str):
        """Automatically pads cipherblock with pkcs7 bytes up to AES block size"""
        # Convert data and pad if necessary
        if isinstance(cipherblock, str):
            cipherblock = cipherblock.encode('utf-8')
            cipherblock = pad(cipherblock, AES.block_size, style = 'pkcs7')
        elif not isinstance(cipherblock, bytes):
            raise ValueError("Cipherblock must be bytes or str")

        await self.init_decryption(init_vec, key, int_f_b(cipherblock[0:16]))
        await self.start_decryption()
        output = byte(await self.get_plaintext())
        data_blocks = round(len(cipherblock)/16)
        for i in range(1, data_blocks):
            self.dut.cipherblock_dec.value = int_f_b(cipherblock[i*16:(i+1)*16])
            await self.start_decryption()
            output += byte(await self.get_plaintext())
        return cipherblock, output