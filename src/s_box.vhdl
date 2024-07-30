library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.std_logic_signed.all;

entity s_box is
port (
    clk         : in std_logic;
    reset       : in std_logic;

    -- INPUT
    input_byte  : in std_logic_vector(7 downto 0);
    input_en    : in std_logic;
    -- OUTPUT
	output_byte : out std_logic_vector(7 downto 0);
    output_en   : out std_logic;
    err         : out std_logic
);
end s_box;

architecture rtl of s_box is
    signal aes_px          : std_logic_vector(18 downto 0);
	
    signal a_x             : std_logic_vector(18 downto 0);
    signal data_ready      : std_logic;
	
    signal ext_euc_ready   : std_logic;
    signal ext_euc_in_prog : std_logic;
    signal ext_euc_done    : std_logic;
    


    type state_type is (EUC_A,EUC_B,EUC_C,EUC_D);
    signal ext_euc_state   : state_type;
    
    type default_states is record
        y_1_d              : std_logic_vector(18 downto 0);
        y_2_d              : std_logic_vector(18 downto 0);
        aes_px_d           : std_logic_vector(18 downto 0);
        ext_euc_state_d    : state_type;
    end record;

    constant INIT_EUC  : default_states := (
        aes_px_d        => "0000000000100011011",
        y_1_d           => "0000000000000000001",
        y_2_d           => (others => '0'),
        ext_euc_state_d => EUC_A
    );
    
    signal y_0             : std_logic_vector(37 downto 0);
    signal y_2             : std_logic_vector(18 downto 0);
    signal y_1             : std_logic_vector(18 downto 0);
    signal q               : std_logic_vector(18 downto 0);
    signal r               : std_logic_vector(37 downto 0);
begin

    input_proc : process(clk)
    begin
        if rising_edge(clk) then
            data_ready <= '0';
            if reset = '1' then
                null;
            else
                if input_en = '1' and ext_euc_ready = '1' then
                    data_ready <= '1'; -- Pulsed
                end if;
            end if;
        end if;
    end process;

    ext_euc_proc: process(clk)
	begin
        if rising_edge(clk) then
            ext_euc_done <= '0';
            if reset = '1' then
                ext_euc_ready   <= '1';
                ext_euc_in_prog <= '0';
                -- Set initial states:
                ext_euc_state   <= INIT_EUC.ext_euc_state_d;
                aes_px          <= INIT_EUC.aes_px_d;
                y_1             <= INIT_EUC.y_1_d;
                y_2             <= INIT_EUC.y_2_d;
            end if; -- reset

            if ext_euc_in_prog = '1' then
                case ext_euc_state is
                    when EUC_A =>
                        if a_x(0) = '1' then
                            -- Algo complete
                            ext_euc_in_prog <= '0';
                            ext_euc_done    <= '1'; -- Pulsed
                        else
                            -- Keep going
                            a_x <= "00000000000" & input_byte;
                            q             <= std_logic_vector(unsigned(aes_px) / unsigned(a_x));
                            r             <= aes_px + q * a_x;
                            ext_euc_state <= EUC_B;
                        end if;
                    when EUC_B =>
                        y_0           <= y_2 + y_1*q;
                        ext_euc_state <= EUC_C;
                    when EUC_C =>
                        y_1           <= y_0(18 downto 0);
                        y_2           <= y_1;
                        ext_euc_state <= EUC_D;
                    when others =>
                        -- EUC_D
                        aes_px        <= a_x;
                        a_x           <= r(18 downto 0);
                        ext_euc_state <= EUC_A;
                end case;

            elsif data_ready = '1' then
                -- First iteration (in here to save a cc)
                if a_x(0) = '1' then
                    -- Check corner case
                    ext_euc_done    <= '1'; -- Pulsed
                else
                    -- Set initial states
                    ext_euc_in_prog <= '1';
                    ext_euc_state   <= INIT_EUC.ext_euc_state_d;
                    aes_px          <= INIT_EUC.aes_px_d;
                    y_1             <= INIT_EUC.y_1_d;
                    y_2             <= INIT_EUC.y_2_d;
                end if;
            end if;
        end if;
	end process;

    output_proc : process(clk)
    begin
        if rising_edge(clk) then
            if ext_euc_done = '1' then
                output_byte <= y_1(7 downto 0);
                output_en   <= '1';
            else
                output_en   <= '0';
            end if;
        end if;
    end process;

end architecture rtl;