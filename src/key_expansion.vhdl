library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std_unsigned.all;
library work;
use work.aes_pkg.all;

entity key_expansion is
port 
(
    -- Common
    clk           : in std_logic;
    reset         : in std_logic;
    -- Input
    key           : in std_logic_vector(127 downto 0);
    input_en      : in std_logic;
    -- Output
	e_key         : out exp_key_type;
    output_en     : out std_logic
);
end key_expansion;

architecture rtl of key_expansion is
    constant NUM_COLS : integer := 4;
    signal expansion_in_prog : std_logic;
    signal index      : integer range 4 to 43;
    signal e_key_i    : exp_key_type;
begin

-- We need to provide 1 key per round
-- ByteSub, ShiftRow, and MixCol take x ccs to complete
-- This means we can take x ccs to output each key. The following implementation
-- assumes this timing.

    ctrl_proc : process(clk)
        variable row_num : integer range 0 to 10;
        variable col_num : integer range 0 to 3;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                expansion_in_prog <= '0';
                index <= 4;
                row_num := 0;
            else
                if input_en = '1' then
                    expansion_in_prog <= '1';
                    e_key_i(row_num) <= key; -- first key is just the input key
                end if;
                if expansion_in_prog = '1' then
                    if is_leftmost(index) = '1' then
                        row_num := row_num + 1; -- assigned immediately
                        -- the leftmost word is derived from:
                        e_key_i(row_num)(127 downto 96) <= e_key_i(row_num-1)(127 downto 96) xor s_box_word(rot_word(e_key_i(row_num-1)(31 downto 0))) xor R_CON(row_num-1);                
                    else
                        -- the other words are derived from:
                        col_num := index-NUM_COLS*row_num;
                        e_key_i(row_num)(127 - col_num*32 downto 96 - col_num*32) <= e_key_i(row_num)(127 - (col_num-1)*32 downto 96 - (col_num-1)*32) xor 
                                                                                    e_key_i(row_num - 1)(127 - col_num*32 downto 96 - col_num*32);
                    end if;

                    if index = 43 then
                        -- last key
                        output_en <= '1';
                        expansion_in_prog <= '0';
                        -- Reset the internal variables so we're ready for a new key next cc
                        index <= 4;
                        row_num := 0;
                        e_key <= e_key_i; -- register the output
                    else
                        -- iterate counter
                        index <= index + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;







