library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std_unsigned.all;
library work;
use work.aes_pkg.all;

entity aes_128_top is
generic
(
    INPUT_BUS_WIDTH : natural range 1 to 16 := 1;
    OUTPUT_BUS_WIDTH : natural range 1 to 16 := 16;
)
port 
(
    -- Common
    clk           : in std_logic;
    reset         : in std_logic;
    -- Input
    input_bus     : in std_logic_vector(INPUT_BUS_WIDTH*8-1 downto 0);
    key           : in std_logic_vector(127 downto 0);
    input_en      : in std_logic;
    -- Output
	e_key         : out std_logic_vector(OUTPUT_BUS_WIDTH*8-1 downto 0);
    output_en     : out std_logic
);
end aes_128_top;

architecture rtl of aes_128_top is
    
begin

    key_expansion_inst : entity work.key_expansion(rtl)
    port map
    (
        -- Common
        clk        =>               -- in std_logic;
        reset      =>               -- in std_logic;
        -- Input
        key        =>               -- in std_logic_vector(127 downto 0);
        input_en   =>               -- in std_logic;
        -- Output
        e_key      =>               -- out exp_key_type;
        output_en  =>               -- out std_logic
    );
    
    s_box_inst : entity work.s_box(rtl)
    generic map
    (
        BUS_WIDTH => INPUT_BUS_WIDTH
    )
    port map
    (
        -- Common
        clk         =>         -- in std_logic;
        reset       =>         -- in std_logic;
        -- Input
        input_bus   =>         -- in std_logic_vector(BUS_WIDTH*8-1 downto 0);
        input_en    =>         -- in std_logic;
        -- Output
        output_bus  =>         -- out std_logic_vector(BUS_WIDTH*8-1 downto 0);
        output_en   =>         -- out std_logic
    );

    shift_rows_inst : entity work.shift_rows(rtl)
    generic map
    (
        NUM_INPUT_BYTES => INPUT_BUS_WIDTH
    )
    port map
    (
        -- Common
        clk          => -- in std_logic;
        reset        => -- in std_logic;
        -- Input
        input_bytes  => -- in std_logic_vector(NUM_INPUT_BYTES*8 - 1 downto 0);
        input_en     => -- in std_logic;
        -- Output
        output_bytes => -- out std_logic_vector(127 downto 0); -- output is always 16*16 bytes
        output_en    => --out std_logic
    );

    mix_columns_inst : entity work.mix_columns(rtl)
    port map
    (
        -- Common
        clk          => -- in std_logic;
        reset        => -- in std_logic;
        -- Input
        input_bytes  => -- in std_logic_vector(127 downto 0);
        input_en     => -- in std_logic;
        -- Output
        output_bytes => -- out std_logic_vector(127 downto 0); -- output is always 16*16 bytes
        output_en    => -- out std_logic
    );

    add_round_key : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                null;
            else
                null;
            end if;
        end if;
    end process;

end architecture rtl;







