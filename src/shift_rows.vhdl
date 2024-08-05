library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std_unsigned.all;

entity shift_rows is
generic
(
    NUM_INPUT_BYTES : natural range 1 to 16     -- # of bytes input to the comp. with each cc. Must be power of 2
);
port 
(
    -- Common
    clk         : in std_logic;
    reset       : in std_logic;
    -- Input
    input_bytes : in std_logic_vector(NUM_INPUT_BYTES*8 - 1 downto 0);
    input_en    : in std_logic;
    -- Output
	output_bytes : out std_logic_vector(127 downto 0); -- output is always 16*16 bytes
    output_en   : out std_logic
);
end shift_rows;

architecture rtl of shift_rows is
    signal frame_byte_index : natural range 0 to 15; --increments by NUM_INPUT_BYTES each cc to point at next memory location to fill with input bytes
    signal data_ready       : std_logic;
    constant END_INDEX      : natural range 0 to 15 := 16 - NUM_INPUT_BYTES; -- Last memory location index, after which we perform shift rows. 

    type aes_array_type is array (0 to 3) of std_logic_vector(31 downto 0); -- TODO: define this in a package
    -- signal byte_array : aes_array_type;
    signal byte_array   : std_logic_vector(127 downto 0);
    signal output_array : std_logic_vector(127 downto 0);
    signal output_ready : std_logic;
begin

    input_proc : process(clk)
    begin
        if rising_edge(clk) then
            data_ready <= '0';
            if reset = '1' then
                frame_byte_index <= 0;
            else
                if input_en = '1' then
                    -- Assign the input to the correct byte array addresses:
                    -- TODO: There is probably a way to directly map the input bytes to the correct indeces for shift rows. This would save 128 FFs
                    byte_array((127 - frame_byte_index*8) downto (128 - NUM_INPUT_BYTES*8) - frame_byte_index*8) <= input_bytes;
                    if frame_byte_index = END_INDEX then    -- 
                        data_ready <= '1';
                        frame_byte_index <= 0; -- clear to start reading in another frame
                    else
                        frame_byte_index <= frame_byte_index + NUM_INPUT_BYTES;
                    end if;
                end if;
            end if;
        end if;
    end process;

    shift_rows_proc : process(clk)
    begin
        if rising_edge(clk) then
            output_ready <= '0';
            if reset = '1' then
                null;
            else
                if data_ready = '1' then
                    -- perform shift rows, register the output
                    output_array(127 downto 96)  <= byte_array(127 downto 96); -- no shift
                    -- output_array(95  downto 64)  <= byte_array(95  downto 64) rol 1;
                    -- output_array(63  downto 32)  <= byte_array(63  downto 32) rol 2;
                    -- output_array(31  downto  0)  <= byte_array(95  downto 64) rol 3;
                    output_array(95  downto 64)  <= byte_array(87 downto 80) & byte_array(79 downto 72) & byte_array(71 downto 64) & byte_array(95 downto 88); -- shift 1
                    output_array(63  downto 32)  <= byte_array(47 downto 40) & byte_array(39 downto 32) & byte_array(63 downto 56) & byte_array(55 downto 48); -- shift 2
                    output_array(31  downto  0)  <= byte_array(7 downto 0) & byte_array(31 downto 24) & byte_array(23 downto 16) & byte_array(15 downto 8);    -- shift 3
                    output_ready <= '1'; -- Pulsed
                end if;
            end if;
        end if;
    end process;

    output_proc : process(clk)
    begin
        if rising_edge(clk) then
            output_en <= '0';
            if reset = '1' then
                null;
            else
                if output_ready = '1' then
                    output_bytes <= output_array;
                    output_en <= '1'; -- Pulsed
                end if;
            end if;
        end if;
    end process;

end architecture rtl;