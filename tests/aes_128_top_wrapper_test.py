import os
import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer
from cocotb_tools.runner import get_runner
from common.common import *

proj_path = Path(__file__).resolve().parent.parent

# equivalent to setting the PYTHONPATH environment variable
sys.path.append(str(proj_path / "tests"))
sys.path.append(str(proj_path / "model"))

ZEROES_128 = 0x00000000000000000000000000000000
ONES_128   = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
# FIPS 197 Appendix B
FIPS_KEY    = 0x2B7E151628AED2A6ABF7158809CF4F3C
FIPS_INPUT  = 0x3243F6A8885A308D313198A2E0370734
FIPS_OUTPUT = 0x3925841D02DC09FBDC118597196A0B32

async def sync(dut, ccs):
    for _ in range(ccs): await RisingEdge(dut.clk)

async def reset(dut):
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    return

async def transmit_block(dut, block):
    """
    Transmits 4 bytes of data on the databus as per interface specifications.
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
    

async def receive_block(dut):
    """
    Receives 4 bytes of data on the databus as per interface specifications.
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
    print(output)
    return unpad(output, AES.block_size)


@cocotb.test()
async def test_1(dut):
    """
    This tests the DUT based on FIPS-197 Appendix B, with one round of encryption and one round of decryption.
    """
    # Create clock
    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start(start_high=False))

    # Reset
    await reset(dut)

    # Encrypt a block
    await transmit_init_sequence(dut, ZEROES_128, FIPS_KEY, FIPS_INPUT)

    # Receive the cipherblock
    return_block_enc = await receive_block(dut)
    assert return_block_enc == FIPS_OUTPUT, f"Error: Encrypted block [{to_hex(return_block_enc)}] did not match expected value [{to_hex(FIPS_OUTPUT)}]."
    
    # Switch to decryption mode
    await switch_dec(dut)
    
    # Decrypt the return value
    await transmit_init_sequence(dut, ZEROES_128, FIPS_KEY, return_block_enc)

    # Receive the plaintext
    return_block_dec = await receive_block(dut)
    assert return_block_dec == FIPS_INPUT, f"Error: Decrypted block [{to_hex(return_block_dec)}] did not match expected value [{to_hex(FIPS_INPUT)}]."

    await sync(dut, 10)

@cocotb.test()
async def test_2(dut):
    """
    Tests one round of AES-128 enc/dec, this time utilizing random numbers and the initial vector.
    """

    # Generate a random initial vector
    init_vec  = random.randint(0,ONES_128)
    key       = random.randint(0,ONES_128)
    plaintext = random.randint(0,ONES_128)

    # Create clock
    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    await reset(dut)

    # Get the expected cipherblock
    expected_enc = encrypt_int_128 (init_vec, key, plaintext)

    # Encrypt a block
    await transmit_init_sequence(dut, init_vec, key, plaintext)

    # Receive the cipherblock
    return_block_enc = await receive_block(dut)
    assert return_block_enc == expected_enc, f"Error: Encrypted block [{to_hex(return_block_enc)}] did not match expected value [{to_hex(expected_enc)}]."
    
    # Switch to decryption mode
    await switch_dec(dut)
    
    # Decrypt the return value
    await transmit_init_sequence(dut, init_vec, key, return_block_enc)

    # Receive the plaintext
    return_block_dec = await receive_block(dut)
    assert return_block_dec == plaintext, f"Error: Decrypted block [{to_hex(return_block_dec)}] did not match expected value [{to_hex(plaintext)}]."

    await sync(dut, 10)

@cocotb.test()
async def test_3(dut):
    """
    Tests multiple rounds of AES-128 enc/dec.
    """

    # Generate data
    iv  = random.randint(0,ONES_128)
    key = random.randint(0,ONES_128)
    data = "This data is not for prying eyes!"
    # Pad the plaintext to be a multiple of the AES block size (16 bytes)
    padded_plaintext = pad(data.encode('utf-8'), AES.block_size)
    print(padded_plaintext)
    enc_data = encrypt_string(iv, key, padded_plaintext)
    # print(decrypt_string(iv,key,enc_data.hex()))

    # Write to files
    src_file = f"{proj_path}/tests/test_3_data_source.txt"
    exp_enc_file = f"{proj_path}/tests/test_3_exp_enc.txt"
    dut_enc_file = f"{proj_path}/tests/test_3_enc.txt"
    dut_dec_file = f"{proj_path}/tests/test_3_dec.txt"

    with open(src_file, 'w') as f:
        f.write(data)
    
    with open(exp_enc_file, 'w') as f:
        f.write(enc_data.hex())

    # Create clock
    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    await reset(dut)

    encoded_bytes = await dut_encode_bytes(dut, iv, key, padded_plaintext)
    print(hex(int_f_b(encoded_bytes)))

    decoded_bytes = await dut_decode_bytes(dut, iv, key, encoded_bytes)
    print(hex(int_f_b(decoded_bytes)))


    await sync(dut, 5)



def test_aes_128_top_wrapper_runner():
    src = "aes_128_top_wrapper"
    sim = os.getenv("SIM", "questa")

    aes_pkg_path    = proj_path / "src" / "common" /"aes_pkg.vhdl"
    key_exp_path    = proj_path / "src" / "common" /"key_expansion.vhdl"
    top_enc_path    = proj_path / "src" / "enc" /"aes_128_top_enc.vhdl"
    mix_cols_path   = proj_path / "src" / "enc" /"mix_columns.vhdl"
    s_box_path      = proj_path / "src" / "enc" /"s_box.vhdl"
    shift_rows_path = proj_path / "src" / "enc" /"shift_rows.vhdl"
    
    top_dec_path  = proj_path / "src" / "dec" /"aes_128_top_dec.vhdl"
    inv_mix_cols_path = proj_path / "src" / "dec" /"inv_mix_columns.vhdl"
    inv_s_box_path = proj_path / "src" / "dec" /"inv_s_box.vhdl"
    inv_shift_rows_path = proj_path / "src" / "dec" /"inv_shift_rows.vhdl"
    
    top_wrapper_path = proj_path / "src" / f"{src}.vhdl"

    sources = [aes_pkg_path, key_exp_path, mix_cols_path,
               s_box_path, shift_rows_path, top_enc_path,
               inv_mix_cols_path, inv_s_box_path, inv_shift_rows_path,
               top_dec_path, top_wrapper_path]
    
    build_arg_im = (f'-wlf {proj_path}/tests/test.wlf')
    
    build_args = []
    test_args = []
    
    runner = get_runner(sim)
    print(sources)
    runner.build(
        sources=sources,
        hdl_toplevel=f"{src}",
        always=True,
        build_args=build_args,
    )
    runner.test(
        hdl_toplevel=f"{src}", 
        test_module=f"{src}_test", 
        test_args=test_args,
        waves = True
    )

if __name__ == "__main__":
    test_aes_128_top_wrapper_runner()