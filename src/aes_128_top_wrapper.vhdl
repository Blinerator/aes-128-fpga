library ieee;
use ieee.std_logic_1164.all;
library work;
use work.aes_pkg.all;

entity aes_128_top_wrapper is
port 
(
    -- Common
    clk       : in std_logic;
    reset     : in std_logic;
    
    start     : in std_logic;
    send_auth : in std_logic;

    done      : out std_logic;
    data_bus  : inout std_logic_vector(31 downto 0)
);
end aes_128_top_wrapper;

architecture rtl of aes_128_top_wrapper is

    type interface_state_type is (idle, read_iv, read_key, read_plaintext, write_cipherblock);
    signal interface_state : key_proc_state_type;

begin

    interface_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                null;
            else
                
            end if;
        end if;
    end process;


    aes_128_top_inst : entity work.aes_128_top(rtl)
    port map
    (
        -- Common
        clk              => clk,   -- in std_logic;
        reset            => reset, -- in std_logic;
        -- Input
        input_bus        =>  -- in std_logic_vector(IBW*8-1 downto 0);
        input_key        =>  -- in std_logic_vector(127 downto 0);
        input_key_valid  =>  -- in std_logic;
        init_vec         =>  -- in std_logic_vector(127 downto 0);
        init_vec_valid   =>  -- in std_logic;
        input_valid      =>  -- in std_logic;                      
        -- Output
        cipherblock      =>  -- out std_logic_vector(OBW*8-1 downto 0);
        output_valid     =>  -- out std_logic
    );

end architecture rtl;