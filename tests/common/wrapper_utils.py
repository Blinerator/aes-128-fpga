# © 2025 Ilya Cable <ilya.cable1@gmail.com>
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
from cocotb.triggers import RisingEdge
from common.common import *

async def transmit_block(dut, block):
    """
    Transmits 16 bytes of data on the databus as per interface specifications.
    """
    for i in range(4):
        input_bytes = (block & (0xFFFFFFFF << 32*(3-i))) >> 32*(3-i)
        dut.data_bus.value = input_bytes
        dut.start.value = 1
        await RisingEdge(dut.clk)
        if dut.done.value != 1:
            await RisingEdge(dut.done)

    dut.start.value = 0
    return

def to_hex(value):
    return "0x" + hex(int(value)).upper()[2:].zfill(8)
    
async def reset(dut):
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    return

async def receive_block(dut):
    """
    Receives 16 bytes of data on the databus as per interface specifications.
    """
    block = 0
    dut.send_auth.value = 1
    await RisingEdge(dut.done)
    for i in range(4):
        dut.start.value = 1
        await sync(dut, 1)
        block += int(dut.data_bus.value) << 32*(3-i)
        if dut.done.value != 1:
            await RisingEdge(dut.done)

    dut.start.value = 0
    dut.send_auth.value = 0
    return block

async def transmit_init_sequence(dut, init_vec, key, data):
    """
    Transmits an initial sequence of the initial vector, key, and data (cipherblock or plaintext)
    """
    await transmit_block(dut, init_vec)
    await transmit_block(dut, key)
    await transmit_block(dut, data)
    return

async def switch_dec(dut):
    """
    Switches to decryption mode as per interface specifications.
    """
    await reset(dut)
    dut.start.value = 1
    dut.send_auth.value = 1
    await sync(dut, 5)
    dut.start.value = 0
    dut.send_auth.value = 0
    return

async def dut_encode_bytes(dut, init_vec, key, data) -> bytes:
    """
    Expects padded bytes.
    """
    await transmit_init_sequence(dut, init_vec, key, int_f_b(data[0:16]))
    output = byte(await receive_block(dut)) # bytes object
    data_blocks = round(len(data)/16)
    for i in range(1, data_blocks):
        await transmit_block(dut, int_f_b(data[i*16:(i+1)*16]))
        output += byte(await receive_block(dut))
    return output

async def dut_decode_bytes(dut, init_vec, key, data) -> bytes:
    """
    Expects a multiple of 16 number of bytes. Returns unpadded bytes.
    """
    await switch_dec(dut)
    await transmit_init_sequence(dut, init_vec, key, int_f_b(data[0:16]))
    output = byte(await receive_block(dut)) # bytes object
    data_blocks = round(len(data)/16)

    for i in range(1, data_blocks):
        await transmit_block(dut, int_f_b(data[i*16:(i+1)*16]))
        output += byte(await receive_block(dut))
    return unpad(output, AES.block_size)
