library ieee;
use ieee.std_logic_1164.all;
library work;
use work.aes_pkg.all;

entity mix_columns is
port 
(
    -- Common
    clk         : in std_logic;
    reset       : in std_logic;
    -- Input
    input_bytes : in std_logic_vector(127 downto 0);
    input_en    : in std_logic;
    -- Output
	output_bytes : out std_logic_vector(127 downto 0); -- output is always 16*16 bytes
    output_en   : out std_logic
);
end mix_columns;

architecture rtl of mix_columns is

    -- Function to mix a single column of 4 bytes. Returns a concatonated 32 bit std_logic_vector
    function mix_col(s_0, s_1, s_2, s_3 : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return (mul_g2(s_0) xor mul_g3(s_1) xor s_2         xor s_3        ) &
               (s_0         xor mul_g2(s_1) xor mul_g3(s_2) xor s_3        ) &
               (s_0         xor s_1         xor mul_g2(s_2) xor mul_g3(s_3)) &
               (mul_g3(s_0) xor s_1         xor s_2         xor mul_g2(s_3));
    end mix_col;

    -- Function to take the cols from mix_cols and return a single output state
    function concat_cols(col_0, col_1, col_2, col_3 : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return col_0(31 downto 24) & col_1(31 downto 24) & col_2(31 downto 24) & col_3(31 downto 24) &
               col_0(23 downto 16) & col_1(23 downto 16) & col_2(23 downto 16) & col_3(23 downto 16) &
               col_0(15 downto 8 ) & col_1(15 downto 8 ) & col_2(15 downto 8 ) & col_3(15 downto 8 ) &
               col_0(7  downto 0 ) & col_1(7  downto 0 ) & col_2(7  downto 0 ) & col_3(7  downto 0 );
    end concat_cols;

    signal data_ready   : std_logic;
    signal byte_array   : std_logic_vector(127 downto 0);
    signal output_array : std_logic_vector(127 downto 0);
    signal output_ready : std_logic;
begin

    input_proc : process(clk)
    begin
        if rising_edge(clk) then
            data_ready <= '0';
            if reset = '1' then
                null;
            else
                if input_en = '1' then
                    byte_array <= input_bytes; -- register the input
                    data_ready <= '1';
                end if;
            end if;
        end if;
    end process;

    mix_cols_proc : process(clk)
    begin
        if rising_edge(clk) then
            output_en <= '0';
            if reset = '1' then
                null;
            else
                if data_ready = '1' then
                    output_bytes <= concat_cols(mix_col(byte_array(127 downto 120), byte_array(95 downto 88), byte_array(63 downto 56), byte_array(31 downto 24)),
                                                mix_col(byte_array(119 downto 112), byte_array(87 downto 80), byte_array(55 downto 48), byte_array(23 downto 16)),
                                                mix_col(byte_array(111 downto 104), byte_array(79 downto 72), byte_array(47 downto 40), byte_array(15 downto 8 )),
                                                mix_col(byte_array(103 downto 96) , byte_array(71 downto 64), byte_array(39 downto 32), byte_array(7 downto  0 )));
                    output_en <= '1'; -- Pulsed
                end if;
            end if;
        end if;
    end process;

end architecture rtl;