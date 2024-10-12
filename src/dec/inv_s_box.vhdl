library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all; -- inv_s_box_byte

entity inv_s_box is
generic
(
    BUS_WIDTH : natural range 1 to 16 -- Width of in/out bus. Each byte on the input bus is replaced by its inverse on the output bus.
);
port 
(
    -- Common
    clk         : in std_logic;
    reset       : in std_logic;
    -- Input
    input_bus   : in std_logic_vector(BUS_WIDTH*8-1 downto 0);
    input_en    : in std_logic;
    -- Output
	output_bus  : out std_logic_vector(BUS_WIDTH*8-1 downto 0);
    output_en   : out std_logic
);
end inv_s_box;

architecture rtl of inv_s_box is
begin

ctrl_proc : process(clk)
begin
    if rising_edge(clk) then
        output_en <= '0'; -- Reset pulse 
        if input_en = '1' then
            -- Assign output_en here, otherwise will be multi-driven if multiple inv_procs are generated
            output_en <= '1'; -- Pulsed
        end if;
    end if;
end process;

gen_sbox : for i in 1 to BUS_WIDTH generate
    inv_proc : process(clk)
    begin
        if rising_edge(clk) then
            if input_en = '1' then
                -- Inversion for each byte in the input bus
                output_bus(i*8-1 downto i*8-8) <= inv_s_box_byte(input_bus(i*8-1 downto i*8-8));
            end if;
        end if;
    end process;
end generate gen_sbox;

end architecture rtl;