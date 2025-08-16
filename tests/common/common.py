# © 2025 Ilya Cable <ilya.cable1@gmail.com>
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
from cocotb.triggers import RisingEdge

def byte(dat : int):
    return dat.to_bytes(16, byteorder='big')

def to_hex(value):
    return "0x" + hex(int(value)).upper()[2:].zfill(8)

def int_f_b(dat):
    return int.from_bytes(dat, 'big', signed=False)

def encrypt_int_128(iv, key, plaintext):
    # Create AES cipher in CBC mode
    cipher = AES.new(byte(key), AES.MODE_CBC, byte(iv))

    # Encrypt the plaintext
    cipherblock = cipher.encrypt(byte(plaintext))
    return int.from_bytes(cipherblock, 'big', signed=False)

def decrypt_int_128(iv, key, cipherblock):
    # Create AES cipher in CBC mode
    cipher = AES.new(byte(key), AES.MODE_CBC, byte(iv))

    # Encrypt the plaintext
    plaintext = cipher.decrypt(byte(cipherblock))
    return int.from_bytes(plaintext, 'big', signed=False)

def encrypt_string(iv : int, key : int, text: bytes, ) -> bytes:
    """
    Expects a padded bytes object.
    """
    # Create AES cipher in CBC mode
    cipher = AES.new(byte(key), AES.MODE_CBC, byte(iv))

    # Encrypt the plaintext
    ciphertext = cipher.encrypt(text)

    return ciphertext

def decrypt_string(iv : int, key : int, block: str, ) -> bytes:
    block = bytes.fromhex(block)
    cipher = AES.new(byte(key), AES.MODE_CBC, byte(iv))
    decrypted_padded = cipher.decrypt(block)
    decrypted_plaintext = unpad(decrypted_padded, AES.block_size)

    return decrypted_plaintext.decode('utf-8')

async def sync(dut, ccs):
    for _ in range(ccs): await RisingEdge(dut.clk)

from Crypto.Util.Padding import pad
ZEROES_128 = 0x00000000000000000000000000000000
ONES_128   = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
import random
iv  = random.randint(0,ONES_128)
key = random.randint(0,ONES_128)
data = "This data is not for prying eyes!"
raw_data = data.encode('utf-8')
padded_plaintext = pad(raw_data, AES.block_size)
exp_enc_bytes = encrypt_string(iv, key, padded_plaintext)

print(f"IV: {to_hex(iv)}")
print(f"Key: {to_hex(key)}")
print(f"Data: {data}")
print(f"Padded plaintext: {padded_plaintext.hex()}")
print(f"Expected encrypted bytes: {exp_enc_bytes.hex()}")