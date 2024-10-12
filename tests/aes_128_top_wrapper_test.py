import os
import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock

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
    raw_data = data.encode('utf-8')
    padded_plaintext = pad(raw_data, AES.block_size)
    exp_enc_bytes = encrypt_string(iv, key, padded_plaintext)

    # Create clock
    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    await reset(dut)

    encoded_bytes = await dut_encode_bytes(dut, iv, key, padded_plaintext)
    assert encoded_bytes == exp_enc_bytes, "Encrypted bytes did not match expected value."

    decoded_bytes = await dut_decode_bytes(dut, iv, key, encoded_bytes)
    assert decoded_bytes == raw_data, "Decrypted bytes did not match expected value."

    await sync(dut, 1)

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