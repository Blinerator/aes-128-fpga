import os
import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer
from cocotb_tools.runner import get_runner

proj_path = Path(__file__).resolve().parent.parent

# equivalent to setting the PYTHONPATH environment variable
sys.path.append(str(proj_path / "tests"))
sys.path.append(str(proj_path / "model"))

# if cocotb.simulator.is_running():
#     from key_expansion_model import key_expansion_model


@cocotb.test()
async def key_expansion_basic_test(dut):
    clock = Clock(dut.clk, 10, units="us")  # Create a 10us period clock on port clk
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))

    # reset
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    # input initial key
    dut.key.value = 0x2B7E1516_28AED2A6_ABF71588_09CF4F3C # key from FIPS-197 Appendix A.1
    dut.input_en.value = 1

    await RisingEdge(dut.clk)
    dut.input_en.value = 0
    await RisingEdge(dut.output_en)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    #output = dut.output_byte.value

    #print(f"Input: 5, output: {str(hex(output))}, expected 0x6B")

    # assert dut.X.value == key_expansion_model(
    #     A, B
    # ), f"Adder result is incorrect: {dut.X.value} != 15"


def test_key_expansion_runner():
    src = "key_expansion"
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "vhd")
    sim = os.getenv("SIM", "questa")

    sources = [proj_path / "src" / "aes_pkg.vhdl", proj_path / "src" / f"{src}.vhdl"]

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
        parameters = {"NUM_INPUT_BYTES": 4},
    )
    runner.test(
        hdl_toplevel=f"{src}", 
        test_module=f"{src}_test", 
        test_args=build_test_args,
        waves = True
    )


if __name__ == "__main__":
    test_key_expansion_runner()