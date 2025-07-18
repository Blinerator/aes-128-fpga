-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all; -- mulg2, mulg3

entity inv_mix_columns is
port 
(
    -- Common
    clk         : in std_logic;
    reset       : in std_logic;
    -- Input
    input_bus   : in std_logic_vector(127 downto 0);
    input_en    : in std_logic;
    -- Output
	output_bus  : out std_logic_vector(127 downto 0); -- output is always 16*16 bytes
    output_en   : out std_logic
);
end inv_mix_columns;

architecture rtl of inv_mix_columns is

    -- Function to mix a single column of 4 bytes. Returns a concatonated 32 bit std_logic_vector
    function mix_col(s_0, s_1, s_2, s_3 : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return (mul_g14(s_0) xor mul_g11(s_1) xor mul_g13(s_2) xor  mul_g9(s_3)) &
               ( mul_g9(s_0) xor mul_g14(s_1) xor mul_g11(s_2) xor mul_g13(s_3)) &
               (mul_g13(s_0) xor  mul_g9(s_1) xor mul_g14(s_2) xor mul_g11(s_3)) &
               (mul_g11(s_0) xor mul_g13(s_1) xor  mul_g9(s_2) xor mul_g14(s_3));
    end mix_col;

    -- Function to take the cols from mix_cols and return a single output state
    function concat_cols(col_0, col_1, col_2, col_3 : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return col_0(31 downto 24) & col_0(23 downto 16) & col_0(15 downto 8) & col_0(7 downto 0) &
               col_1(31 downto 24) & col_1(23 downto 16) & col_1(15 downto 8) & col_1(7 downto 0) &
               col_2(31 downto 24) & col_2(23 downto 16) & col_2(15 downto 8) & col_2(7 downto 0) &
               col_3(31 downto 24) & col_3(23 downto 16) & col_3(15 downto 8) & col_3(7 downto 0);
    end concat_cols;

begin

    input_proc : process(clk)
    begin
        if rising_edge(clk) then
            output_en <= '0'; -- Reset pulse
            if input_en = '1' then
                output_bus <= concat_cols(  mix_col(input_bus(127 downto 120), input_bus(119 downto 112), input_bus(111 downto 104), input_bus(103 downto 96)),
                                            mix_col(input_bus(95 downto 88)  , input_bus(87 downto 80)  , input_bus(79 downto 72)  , input_bus(71 downto 64 )),
                                            mix_col(input_bus(63 downto 56)  , input_bus(55 downto 48)  , input_bus(47 downto 40)  , input_bus(39 downto 32 )),
                                            mix_col(input_bus(31 downto 24)  , input_bus(23 downto 16)  , input_bus(15 downto 8)   , input_bus(7 downto  0  )));
                output_en <= '1'; -- Pulsed
            end if;
        end if;
    end process;

end architecture rtl;