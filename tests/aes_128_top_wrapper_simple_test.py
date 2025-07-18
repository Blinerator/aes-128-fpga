# © 2025 Ilya Cable <ilya.cable1@gmail.com>
import os
import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock

from cocotb_tools.runner import get_runner
from common.common import *
from common.wrapper_simple_utils import *

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

@cocotb.test(timeout_time=2000, timeout_unit='ns')
async def test_1(dut):
    """
    This tests the DUT based on FIPS-197 Appendix B, with one round of encryption and one round of decryption.
    """
    # Create clock
    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start(start_high=False))

    # Initialise testbench class
    tb = TB(dut)

    # Reset
    await tb.reset()

    # Encrypt a block
    # Place initial vector on init_vec_enc
    await tb.init_encryption(ZEROES_128, FIPS_KEY, FIPS_INPUT)

    # Pulse start_enc
    await tb.start_encryption()

    return_block_enc = await tb.get_cipherblock()

    assert return_block_enc == FIPS_OUTPUT, f"Error: Encrypted block [{to_hex(return_block_enc)}] did not match expected value [{to_hex(FIPS_OUTPUT)}]."
    
    # Try the decryption interface
    await tb.init_decryption(ZEROES_128, FIPS_KEY, return_block_enc)

    # Pulse start_dec
    await tb.start_decryption()

    # Receive the plaintext
    return_block_dec = await tb.get_plaintext()

    assert return_block_dec == FIPS_INPUT, f"Error: Decrypted block [{to_hex(return_block_dec)}] did not match expected value [{to_hex(FIPS_INPUT)}]."

    await sync(dut, 10)

@cocotb.test(timeout_time=2000, timeout_unit='ns')
async def test_2(dut):
    """
    Tests one round of AES-128 enc/dec, this time utilizing random numbers and the initial vector.
    """

    # Initialise testbench class
    tb = TB(dut)

    # Generate a random initial vector
    init_vec  = random.randint(0,ONES_128)
    key       = random.randint(0,ONES_128)
    plaintext = random.randint(0,ONES_128)

    # Create clock
    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    await tb.reset()

    # Get the expected cipherblock
    expected_enc = encrypt_int_128(init_vec, key, plaintext)

    # Encrypt a block
    await tb.init_encryption(init_vec, key, plaintext)
    await tb.start_encryption()

    # Receive the cipherblock
    return_block_enc = await tb.get_cipherblock()
    assert return_block_enc == expected_enc, f"Error: Encrypted block [{to_hex(return_block_enc)}] did not match expected value [{to_hex(expected_enc)}]."
    
    # Decrypt the return value
    await tb.init_decryption(init_vec, key, return_block_enc)
    await tb.start_decryption()

    # Receive the plaintext
    return_block_dec = await tb.get_plaintext()
    assert return_block_dec == plaintext, f"Error: Decrypted block [{to_hex(return_block_dec)}] did not match expected value [{to_hex(plaintext)}]."

    await sync(dut, 10)

@cocotb.test(timeout_time=10000, timeout_unit='ns')
async def test_3(dut):
    """
    Tests multiple rounds of AES-128 enc/dec.
    """

    # Generate data
    iv  = random.randint(0,ONES_128)
    key = random.randint(0,ONES_128)
    data = "This data is not for prying eyes!"
    raw_data = data.encode('utf-8')
    padded_plaintext = pad(raw_data, AES.block_size)
    exp_enc_bytes = encrypt_string(iv, key, padded_plaintext)
    # Create clock
    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start())
    tb = TB(dut)

    # Reset
    await tb.reset()

    plaintext, encoded_bytes = await tb.dut_encode(iv, key, data)
    # exp_enc_bytes = encrypt_string(iv, key, plaintext)

    assert encoded_bytes == exp_enc_bytes, \
        f"Encrypted bytes did not match expected value.\nExpected:{exp_enc_bytes}\n Actual:{encoded_bytes}"

    _, decoded_bytes = await tb.dut_decode(iv, key, encoded_bytes)
    assert decoded_bytes == plaintext, "Decrypted bytes did not match expected value."

    await sync(dut, 1)

def test_aes_128_top_wrapper_simple_runner():
    src = "aes_128_top_wrapper_simple"
    sim = os.getenv("SIM", "questa")

    aes_pkg_path    = proj_path/"src"/"common"/"aes_pkg.vhd"
    key_exp_path    = proj_path/"src"/"common"/"key_expansion.vhd"
    control_fsm_path = proj_path/"src"/"common"/"control_fsm.vhd"

    top_enc_path    = proj_path/"src"/"enc"/"aes_128_top_enc.vhd"
    mix_cols_path   = proj_path/"src"/"enc"/"mix_columns.vhd"
    s_box_path      = proj_path/"src"/"enc"/"s_box.vhd"
    shift_rows_path = proj_path/"src"/"enc"/"shift_rows.vhd"
    enc_wrapper_path = proj_path/"src"/"wrappers"/"enc_wrapper.vhd"

    top_dec_path  = proj_path/"src"/"dec"/"aes_128_top_dec.vhd"
    inv_mix_cols_path = proj_path/"src"/"dec"/"inv_mix_columns.vhd"
    inv_s_box_path = proj_path/"src"/"dec"/"inv_s_box.vhd"
    inv_shift_rows_path = proj_path/"src"/"dec"/"inv_shift_rows.vhd"
    dec_wrapper_path = proj_path/"src"/"wrappers"/"dec_wrapper.vhd"
    
    top_wrapper_path = proj_path/"src"/f"{src}.vhd"

    sources = [aes_pkg_path, key_exp_path, control_fsm_path, mix_cols_path,
               s_box_path, shift_rows_path, top_enc_path, enc_wrapper_path,
               inv_mix_cols_path, inv_s_box_path, inv_shift_rows_path,
               top_dec_path, dec_wrapper_path, top_wrapper_path]
    
    build_arg_im = (f'-wlf {proj_path}/tests/test.wlf')
    
    build_args = []
    test_args = ['-no_autoacc', "-voptargs=+acc=rnb"] # Don't optimize away signals
    
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
        waves = True,
        parameters = {"MODE" : "ENC_DEC"}
    )

if __name__ == "__main__":
    test_aes_128_top_wrapper_simple_runner()