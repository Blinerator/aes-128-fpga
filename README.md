# AES-128

# Overview

This project implements AES-128 on an inexpensive IO-limited FPGA.

# Components

The design is broken up into the following components to make verification easier:

- aes_top
- swap_bytes
- s_box
- 
# Simulation Instructions

To run testbenches, you will need the following:
- [cocotb](https://docs.cocotb.org/en/stable/install.html)
- Mentor/Siemens EDA Questa 22.1+ ([setup](https://vhdlwhiz.com/free-vhdl-simulator-alternatives/))