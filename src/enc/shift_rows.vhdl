library ieee;
use ieee.std_logic_1164.all;

entity shift_rows is
port 
(
    -- Common
    clk         : in std_logic;
    reset       : in std_logic;
    -- Input
    input_bus   : in std_logic_vector(127 downto 0);
    input_en    : in std_logic;
    -- Output
	output_bus  : out std_logic_vector(127 downto 0);
    output_en   : out std_logic
);
end shift_rows;

architecture rtl of shift_rows is
begin

    input_proc : process(clk)
    begin
        if rising_edge(clk) then
            output_en <= '0';
            if input_en = '1' then
                output_bus(127 downto 96) <= input_bus(127 downto 120) & input_bus(87 downto 80)   & input_bus(47 downto 40)   & input_bus(7  downto 0);
                output_bus(95  downto 64) <= input_bus(95  downto  88) & input_bus(55 downto 48)   & input_bus(15 downto 8 )   & input_bus(103 downto 96);
                output_bus(63  downto 32) <= input_bus(63  downto  56) & input_bus(23 downto 16)   & input_bus(111 downto 104) & input_bus(71 downto 64);
                output_bus(31  downto 0 ) <= input_bus(31  downto  24) & input_bus(119 downto 112) & input_bus(79 downto 72)   & input_bus(39 downto 32);
                output_en <= '1'; -- Pulsed
            end if;
        end if;
    end process;

end architecture rtl;