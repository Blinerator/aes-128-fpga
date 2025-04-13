---------------------------------------------------------------------
-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
--
-- Description: Provides a single place for the simple AES control FSM,
--              since it's the same for both encryption and decryption.
--
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all;

entity control_fsm is
port 
(
    clk       : in std_logic;
    reset     : in std_logic;

    -- Input
    start              : in std_logic;  
    expansion_done     : in std_logic;       
    crypt_output_valid : in std_logic;

    -- Output
    key_valid          : out std_logic;       
    start_crypt        : out std_logic;
    done               : out std_logic  
);
end control_fsm;

architecture rtl of control_fsm is
    type control_state_type is (idle, initial_setup, do_crypt, wait_for_in_data);
    signal control_state : control_state_type;
begin
    control_proc: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                control_state <= idle;
            else
                -- Clear pulsed signals
                key_enc_valid <= '0';
                start_crypt <= '0';
                
                -- Controller FSM
                case control_state is
                    ------------------------------
                    when initial_setup => 
                        if expansion_done = '1' then
                            start_crypt <= '1'; -- Pulsed
                            state <= do_crypt;
                        end if;
                    
                    ------------------------------
                    when do_crypt =>
                        if crypt_output_valid = '1' then
                            control_state <= wait_for_in_data;
                            done <= '1';
                        end if;

                    ------------------------------
                    when wait_for_in_data =>
                        if start = '1' then
                            done <= '0';
                            control_state <= do_crypt;
                        end if;

                    ------------------------------
                    when other => -- idle
                        if start = '1' then
                            key_valid <= '1'; -- Pulsed
                            control_state <= initial_setup;
                        end if;
            end if; -- reset
        end if; -- clk
    end process control_proc;

end architecture rtl;
