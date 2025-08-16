-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
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

architecture lookup of inv_s_box is
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

end architecture lookup;

architecture combinational of inv_s_box is
    -- Signals for mult_inv instances
    type mult_inv_input_array is array (1 to BUS_WIDTH) of std_logic_vector(7 downto 0);
    type mult_inv_output_array is array (1 to BUS_WIDTH) of std_logic_vector(7 downto 0);
    
    signal mult_inv_inputs  : mult_inv_input_array;
    signal mult_inv_outputs : mult_inv_output_array;
    
    -- Pipeline delay registers for output_en (4 clock cycles total: 3 from mult_inv + 1 from inv_proc)
    signal input_en_d : std_logic;
    signal input_en_dd : std_logic;
    signal input_en_ddd : std_logic;

begin

ctrl_proc : process(clk)
begin
    if rising_edge(clk) then
        -- 4-stage pipeline delay for output_en to match total latency
        input_en_d <= input_en;
        input_en_dd <= input_en_d;
        input_en_ddd <= input_en_dd;
        output_en <= input_en_ddd;
    end if;
end process;

gen_sbox : for i in 1 to BUS_WIDTH generate
    mult_inv_inputs(i) <= inv_affine_transform(input_bus(i*8-1 downto i*8-8));
    
    -- Instantiate multiplicative inverse module
    mult_inv_inst : entity work.mult_inv
        port map (
            clk    => clk,
            input  => mult_inv_inputs(i),
            output => mult_inv_outputs(i)
        );
    
    inv_proc : process(clk)
    begin
        if rising_edge(clk) then
            if input_en = '1' then
                output_bus(i*8-1 downto i*8-8) <= mult_inv_outputs(i);
            end if;
        end if;
    end process;
end generate gen_sbox;

end architecture combinational;