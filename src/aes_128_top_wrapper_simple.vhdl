---------------------------------------------------------------------
-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
--
-- Description: An implementation of AES exposing enc/dec signals directly
--              on the port map. Intended to be hooked up to registers externally
--              and used with neorv32 (https://github.com/stnolting/neorv32) as a 
--              custom hardware module in neorv32_cfs.vhd.
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all;
entity aes_128_top_wrapper_simple is
generic
(
    MODE : string -- ENC, DEC, ENC_DEC
);
port 
(
    clk       : in std_logic;
    reset_enc : in std_logic;
    reset_dec : in std_logic;

    -- Encryption Interface
    init_vec_enc    : in std_logic_vector(127 downto 0);       
    key_enc         : in std_logic_vector(127 downto 0);  
    plaintext_enc   : in std_logic_vector(127 downto 0);        
    cipherblock_enc : out std_logic_vector(127 downto 0);          
    start_enc       : in std_logic;    
    done_enc        : out std_logic;    

    -- Decryption Interface
    init_vec_dec    : in std_logic_vector(127 downto 0);       
    key_dec         : in std_logic_vector(127 downto 0);  
    cipherblock_dec : in std_logic_vector(127 downto 0);        
    plaintext_dec   : out std_logic_vector(127 downto 0);          
    start_dec       : in std_logic;    
    done_dec        : out std_logic
);
end aes_128_top_wrapper_simple;

architecture rtl of aes_128_top_wrapper_simple is
begin
    assert MODE = "ENC" or MODE = "DEC" or MODE = "ENC_DEC" 
        report "Error: MODE setting was invalid" severity failure;
    
    mode_gen_1 : if MODE = "ENC" or MODE = "ENC_DEC" generate
        enc_inst : entity work.enc_wrapper(rtl)
        port map
        (
            clk         => clk,
            reset       => reset_enc,
        
            init_vec    => init_vec_enc,   
            key         => key_enc,
            plaintext   => plaintext_enc,    
            cipherblock => cipherblock_enc,       
            start       => start_enc,
            done        => done_enc
        );
    end generate mode_gen_1;
    mode_gen_2 : if MODE = "DEC" or MODE = "ENC_DEC" generate
        dec_inst : entity work.dec_wrapper(rtl)
        port map
        (
            clk         => clk,
            reset       => reset_dec,
        
            init_vec    => init_vec_dec,   
            key         => key_dec,
            cipherblock => cipherblock_dec,       
            plaintext   => plaintext_dec,    
            start       => start_dec,
            done        => done_dec
        );
    end generate mode_gen_2;

end architecture rtl;
