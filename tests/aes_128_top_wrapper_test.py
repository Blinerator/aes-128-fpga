import os
import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer
from cocotb_tools.runner import get_runner
import common.common as common

proj_path = Path(__file__).resolve().parent.parent

# equivalent to setting the PYTHONPATH environment variable
sys.path.append(str(proj_path / "tests"))
sys.path.append(str(proj_path / "model"))

async def sync(dut, ccs):
    for _ in range(ccs): await RisingEdge(dut.clk)

async def reset(dut):
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    return

async def transmit_block(dut, block):
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

# FIPS 197 Appendix B
init_vec = 0x00000000000000000000000000000000
fips_key = 0x2B7E151628AED2A6ABF7158809CF4F3C
fips_input = 0x3243F6A8885A308D313198A2E0370734
fips_output = 0x3925841D02DC09FBDC118597196A0B32

@cocotb.test()
async def test_enc(dut):

    clock = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk (125MHz)
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))

    tb = common.testbench(dut)
    
    await reset(dut)
    # Encrypt a block
    await transmit_block(dut, init_vec)
    await transmit_block(dut, fips_key)
    await transmit_block(dut, fips_input)
    await sync(dut, 1)
    # Receive the cipherblock
    return_block = await receive_block(dut)
    assert return_block == fips_output, f"Error: Encrypted block [{to_hex(return_block)}] did not match expected value [{to_hex(fips_output)}]."

    await sync(dut, 10)

@cocotb.test()
async def test_dec(dut):
    clock = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk (125MHz)
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start())

    await reset(dut)
    
    # Switch to decryption mode
    dut.start.value = 1
    dut.send_auth.value = 1
    sync(dut, 5)
    dut.start.value = 0
    dut.send_auth.value = 0    
    

    # Decrypt a block
    await transmit_block(dut, init_vec)
    await transmit_block(dut, fips_key)
    await transmit_block(dut, fips_output)
    await sync(dut, 1)
    # Receive the cipherblock
    return_block = await receive_block(dut)
    assert return_block == fips_output, f"Error: Decrypted block [{to_hex(return_block)}] did not match expected value [{to_hex(fips_input)}]."

    await sync(dut, 10)

def test_aes_128_top_wrapper_runner():
    src = "aes_128_top_wrapper"
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "vhd")
    sim = os.getenv("SIM", "questa")

    aes_pkg_path  = proj_path / "src" / "common" /"aes_pkg.vhdl"
    key_exp_path  = proj_path / "src" / "common" /"key_expansion.vhdl"
    top_enc_path  = proj_path / "src" / "enc" /"aes_128_top_enc.vhdl"
    mix_cols_path = proj_path / "src" / "enc" /"mix_columns.vhdl"
    s_box_path = proj_path / "src" / "enc" /"s_box.vhdl"
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