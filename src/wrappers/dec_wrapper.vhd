---------------------------------------------------------------------
-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
--
-- Description: Wraps encryption/control logic.
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all;

entity dec_wrapper is
generic
(
    SBOX_ARCHITECTURE : string -- LOOKUP, COMB, MASKED
);
port 
(
    clk       : in std_logic;
    reset     : in std_logic;

    init_vec    : in std_logic_vector(127 downto 0);       
    key         : in std_logic_vector(127 downto 0);  
    cipherblock : in std_logic_vector(127 downto 0);        
    plaintext   : out std_logic_vector(127 downto 0);          
    start       : in std_logic;    
    done        : out std_logic
);
end dec_wrapper;

architecture rtl of dec_wrapper is
    signal expansion_done     : std_logic;
    signal crypt_output_valid : std_logic;
    signal key_valid          : std_logic;
    signal iv_valid           : std_logic;
    signal start_crypt        : std_logic;
    signal e_key              : exp_key_type;

begin
    control_inst : entity work.control_fsm(rtl)
    port map
    (
        clk   => clk,
        reset => reset,

        -- Input
        start              => start,  
        expansion_done     => expansion_done,       
        crypt_output_valid => crypt_output_valid,

        -- Output
        key_valid          => key_valid,       
        start_crypt        => start_crypt,
        iv_valid           => iv_valid,
        done               => done 
    );

    key_expansion_inst : entity work.key_expansion(rtl)
    port map
    (
        -- Common
        clk             => clk,              
        reset           => reset,            
        -- Input
        key             => key,        
        input_en        => key_valid,  
        -- Output
        e_key           => e_key,            
        expansion_done  => expansion_done    
    );

    dec_inst : entity work.aes_128_top_dec(rtl)
    generic map
    (
        SBOX_ARCHITECTURE => SBOX_ARCHITECTURE
    )
    port map
    (
        -- Common
        clk              => clk,                
        reset            => reset,              
        -- Input
        input_bus        => cipherblock,      
        e_key            => e_key,              
        init_vec         => init_vec,           
        init_vec_valid   => iv_valid, 
        input_valid      => start_crypt,    
        -- Output
        plaintext        => plaintext,      
        output_valid     => crypt_output_valid    
    );

end architecture rtl;