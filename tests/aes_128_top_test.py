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

@cocotb.test()
async def aes_128_top_basic_test(dut):
    clock = Clock(dut.clk, 8, units="ns")  # Create a 8ns period clock on port clk (125MHz)
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))

    tb = common.testbench(dut)
    tb.reset()
    # input initial key
    dut.input_key.value = 0x2B7E151628AED2A6ABF7158809CF4F3C # key from FIPS-197 Appendix B
    dut.input_key_valid.value = 1
    # input the input
    plaintext = 0x3243F6A8885A308D313198A2E0370734 # input from FIPS-197 Appendix B
    
    dut.input_bus.value = 0x3243F6A8
    dut.input_valid.value = 1
    await RisingEdge(dut.clk)
    dut.input_bus.value = 0x885A308D
    dut.input_key_valid.value = 0
    await RisingEdge(dut.clk)
    dut.input_bus.value = 0x313198A2
    await RisingEdge(dut.clk)
    dut.input_bus.value = 0xE0370734 
    await RisingEdge(dut.clk)
    dut.input_valid.value = 0
    await RisingEdge(dut.clk)
    # Input initial vector
    dut.init_vec.value = 0x00000000000000000000000000000000
    dut.init_vec_valid.value = 1
    await RisingEdge(dut.clk)
    dut.init_vec_valid.value = 0
    await RisingEdge(dut.output_valid)
    assert dut.cipherblock.value == 0x3925841D02DC09FBDC118597196A0B32, f"Error: incorrect cipherblock value." # FIPS 197 " "
    for _ in range(10):
        await RisingEdge(dut.clk)

def test_aes_128_top_runner():
    src = "aes_128_top_enc"
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "vhd")
    sim = os.getenv("SIM", "questa")

    sources = [proj_path / "src" / "common" /"aes_pkg.vhdl", proj_path / "src" / "common" /"key_expansion.vhdl", 
               proj_path / "src" / "enc" /"s_box.vhdl", proj_path / "src" / "enc" /"shift_rows.vhdl",
               proj_path / "src" / "enc" /"mix_columns.vhdl", proj_path / "src" / "enc" /f"{src}.vhdl"]
    
    build_test_args = []
    if hdl_toplevel_lang == "vhdl" and sim == "xcelium":
        build_test_args = ["-v93"]

    runner = get_runner(sim)
    print(sources)
    runner.build(
        sources=sources,
        hdl_toplevel=f"{src}",
        always=True,
        build_args=build_test_args,
        parameters = {"IBW": 4,"OBW" : 16},
    )
    runner.test(
        hdl_toplevel=f"{src}", 
        test_module=f"{src}_test", 
        test_args=build_test_args,
        waves = True
    )


if __name__ == "__main__":
    test_aes_128_top_runner()