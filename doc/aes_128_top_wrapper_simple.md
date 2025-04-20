# aes_128_top_wrapper_simple
# Block Diagram
<img src="figures/block_diagram_simple.drawio.png" alt="" width="1000"/>

# External Interface

**Table 1: Port Map**

| Name           | Width | Direction | Description 
|----------------|-------|-----------|------------
| clk            | 1     | In        | External reference clock
| reset          | 1     | In        | Synchronous reset
|**Encryption Interface**|||
| init_vec_enc    | 128   | In        | Initial vector
| key_enc         | 128   | In        | Key
| plaintext_enc   | 128   | In        | Plaintext
| cipherblock_enc | 128   | Out       | Encrypted plaintext
| start_enc       | 1     | In        | Start signal
| done_enc        | 1     | Out       | Done signal
|**Decryption Interface**|||
| init_vec_dec    | 128   | In        | Initial vector
| key_dec         | 128   | In        | Key
| cipherblock_dec | 128   | In        | Cipherblock to decrypt
| plaintext_dec   | 128   | Out       | Decrypted plaintext
| start_dec       | 1     | In        | Start signal
| done_dec        | 1     | Out       | Done signal

## Control Scheme Specifications
Both encryption and decryption interfaces work the same way. Inputs should be registered. Outputs are registered internally:
1. Place the initial vector on `init_vec_*`.
2. Place the key on `key_*`.
3. Place the first plaintext/cipherblock on `plaintext_enc`/`cipherblock_dec`.
4. Pulse `start_*`.
5. Once `done_*` asserts, place the next plaintext on plaintext_enc and pulse `start_*` again. `done_*` will automatically deassert.
6. Repeat the sequence until all plaintexts are encrypted.
7. To change the initial vector and/or key, pulse reset and repeat steps (1-6).

Two copies of the same FSM are used to control encryption and decryption:
<img src="figures/control_fsm_simple.drawio.png" alt="" width="500"/>

# Simulation Instructions
To run testbenches, follow the [environment setup](env-setup.md). Debian on WSL was used for the setup instructions, but the basic steps should remain the same.

Run `python3 {testname.py}` to run a test. `aes_128_top_wrapper_simple_test.py` interfaces with `aes_128_top_wrapper_simple.vhdl` through the external interface and implements three tests:

1. Tests the DUT based on FIPS-197 Appendix B, with one round of encryption and decryption.
2. Tests the DUT using random initial vector, key, and plaintext, with one round of encryption and decryption.
3. Tests the CBC mode of the DUT, encrypting and decrypting a string of words. Checks the outputs against the same string encrypted with the "pycryptodome" python library.