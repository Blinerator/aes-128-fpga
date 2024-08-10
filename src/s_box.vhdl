library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std_unsigned.all;
library work;
use work.aes_pkg.all;

entity s_box is
generic
(
    -- Width of in/out bus. Each byte on the input bus is replaced by its inverse on the output bus.
    -- Defaults to 1 byte/cc. Extra 4 bytes available for key expansion.
    BUS_WIDTH : natural range 1 to (16 + 4) := 4
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
	output_bus : out std_logic_vector(BUS_WIDTH*8-1 downto 0);
    output_en   : out std_logic
);
end s_box;

architecture rtl of s_box is



    signal inv : std_logic_vector(BUS_WIDTH*8-1 downto 0);
    signal data_ready : std_logic;
    signal delay_sr   : std_logic_vector(1 downto 0);
begin

ctrl_proc : process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            delay_sr <= (others => '0');
        else
            if input_en = '1' then
                data_ready  <= '1';
                delay_sr(0) <= '1';
            else
                delay_sr <= delay_sr(delay_sr'high - 1 downto 0) & '0'; -- shift left
                output_en <= delay_sr(delay_sr'high - 1); -- S-box is deterministic. It will always take 2 ccs to finish.
            end if;
        end if;
    end if;
end process;
                


gen_sbox : for i in 1 to BUS_WIDTH generate
    input_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                null;
            else
                if input_en = '1' then
                    -- Inversion for each byte in the input bus
                    inv(i*8-1 downto i*8-8) <= s_box_lookup(input_bus(i*8-1 downto i*8-8));
                end if;
            end if;
        end if;
    end process;
end generate gen_sbox;

gen_affine : for i in 0 to BUS_WIDTH-1 generate
    sbox_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                null;
            elsif data_ready = '1' then
                -- Affine for each byte in the input bus
                output_bus(i*8 + 0) <= inv(i*8 + 0) xor inv(i*8 + 4) xor inv(i*8 + 5) xor inv(i*8 + 6) xor inv(i*8 + 7) xor '1';
                output_bus(i*8 + 1) <= inv(i*8 + 0) xor inv(i*8 + 1) xor inv(i*8 + 5) xor inv(i*8 + 6) xor inv(i*8 + 7) xor '1';
                output_bus(i*8 + 2) <= inv(i*8 + 0) xor inv(i*8 + 1) xor inv(i*8 + 2) xor inv(i*8 + 6) xor inv(i*8 + 7) xor '0';
                output_bus(i*8 + 3) <= inv(i*8 + 0) xor inv(i*8 + 1) xor inv(i*8 + 2) xor inv(i*8 + 3) xor inv(i*8 + 7) xor '0';
                output_bus(i*8 + 4) <= inv(i*8 + 0) xor inv(i*8 + 1) xor inv(i*8 + 2) xor inv(i*8 + 3) xor inv(i*8 + 4) xor '0';
                output_bus(i*8 + 5) <= inv(i*8 + 1) xor inv(i*8 + 2) xor inv(i*8 + 3) xor inv(i*8 + 4) xor inv(i*8 + 5) xor '1';
                output_bus(i*8 + 6) <= inv(i*8 + 2) xor inv(i*8 + 3) xor inv(i*8 + 4) xor inv(i*8 + 5) xor inv(i*8 + 6) xor '1';
                output_bus(i*8 + 7) <= inv(i*8 + 3) xor inv(i*8 + 4) xor inv(i*8 + 5) xor inv(i*8 + 6) xor inv(i*8 + 7) xor '0';
            end if;
        end if;
    end process;
end generate gen_affine;

end architecture rtl;