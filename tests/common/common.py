from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer

def byte(dat : int):
    return dat.to_bytes(16, byteorder='big')

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
    # Convert the text into bytes
    # plaintext_bytes = text.encode('utf-8')
    block = bytes.fromhex(block)
    # Create AES cipher in CBC mode
    cipher = AES.new(byte(key), AES.MODE_CBC, byte(iv))

   # Decrypt the ciphertext
    decrypted_padded = cipher.decrypt(block)

    # Unpad the decrypted plaintext
    decrypted_plaintext = unpad(decrypted_padded, AES.block_size)

    # Return the IV + ciphertext (both needed for decryption)
    return decrypted_plaintext.decode('utf-8')

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
