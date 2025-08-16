-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
-- Multiplicative Inversion Module for AES S-Box
-- Implements combinational multiplicative inverse in GF(2^8) using composite field arithmetic

library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all;

entity mult_inv is
    port (
        clk    : in  std_logic;
        input  : in  std_logic_vector(7 downto 0);
        output : out std_logic_vector(7 downto 0)
    );
end entity mult_inv;

architecture rtl of mult_inv is
    signal q_mapped : std_logic_vector(7 downto 0);
    signal q_high   : std_logic_vector(3 downto 0);
    signal q_low    : std_logic_vector(3 downto 0);
    
    signal q_high_reg : std_logic_vector(3 downto 0);
    signal q_low_reg  : std_logic_vector(3 downto 0);
    
    signal temp1  : std_logic_vector(3 downto 0);
    signal temp2  : std_logic_vector(3 downto 0);
    signal temp3  : std_logic_vector(3 downto 0);
    signal temp4  : std_logic_vector(3 downto 0);
    signal temp5  : std_logic_vector(3 downto 0);
    signal temp6  : std_logic_vector(3 downto 0);
    
    signal temp6_reg : std_logic_vector(3 downto 0);
    signal temp2_reg : std_logic_vector(3 downto 0);
    signal q_high_reg2 : std_logic_vector(3 downto 0);
    
    signal temp7 : std_logic_vector(7 downto 0);

begin
    -- Combinational logic: Apply isomorphic mapping and split
    q_mapped <= isomorphic_map_gf8(input);
    q_high <= q_mapped(7 downto 4);
    q_low  <= q_mapped(3 downto 0);
    
    -- Register Stage 1: Register before XOR of top and bottom halves
    process(clk)
    begin
        if rising_edge(clk) then
            q_high_reg <= q_high;
            q_low_reg  <= q_low;
        end if;
    end process;
    
    -- Combinational logic: Composite field operations using registered values
    temp2 <= gf4_add(q_low_reg, q_high_reg);     -- XOR operation in GF(2^4)
    temp3 <= gf4_mul(temp2, q_low_reg);          -- Multiply (q_low XOR q_high) with q_low
    temp1 <= gf4_square(q_high_reg);             -- q_high^2
    temp4 <= gf4_mul_lambda(temp1);              -- temp1 * lambda
    temp5 <= gf4_add(temp4, temp3);              -- norm = (temp4 + temp3)
    temp6 <= gf4_inv(temp5);                     -- Multiplicative inverse of temp5
    
    -- Register Stage 2: Register after inversion
    process(clk)
    begin
        if rising_edge(clk) then
            temp6_reg   <= temp6;
            temp2_reg   <= temp2;
            q_high_reg2 <= q_high_reg;
        end if;
    end process;
    
    -- Combinational logic: Final multiplication and inverse mapping
    temp7(3 downto 0) <= gf4_mul(temp2_reg, temp6_reg);
    temp7(7 downto 4) <= gf4_mul(q_high_reg2, temp6_reg);
    
    -- Register Stage 3: Final output register
    process(clk)
    begin
        if rising_edge(clk) then
            output <= inv_isomorphic_map_gf8(temp7);
        end if;
    end process;

end architecture rtl;
