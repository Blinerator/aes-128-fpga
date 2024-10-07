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

    type interface_state_type is (idle, read_iv, read_key, read_block, 
                                  write_block,wait_output,return_datablock);
    signal interface_state : interface_state_type;
    
    type enc_dec_type is (encryption, decryption);
    signal enc_dec_state : enc_dec_type;

    signal init_vec      : std_logic_vector(127 downto 0);
    signal input_key     : std_logic_vector(127 downto 0);
    signal data_block_in : std_logic_vector(127 downto 0);
    signal datablock_enc : std_logic_vector(127 downto 0);
    signal datablock_dec : std_logic_vector(127 downto 0);
    signal enc_en        : std_logic;
    signal dec_en        : std_logic;
    signal mode          : std_logic;    

    signal input_key_valid : std_logic;
    
    -- Internal signals:
    signal mode_sel_sr    : std_logic_vector(4 downto 0); -- Count 5 ccs 

    signal e_key          : exp_key_type;
    signal input_bus      : std_logic_vector(127 downto 0);
    signal init_vec_valid : std_logic;
    signal input_valid    : std_logic;
    signal expansion_done : std_logic;
    signal first_block      : std_logic;

    -- enc/dec input muxing
    signal init_vec_valid_enc : std_logic;
    signal init_vec_valid_dec : std_logic;
    signal input_valid_enc    : std_logic;
    signal input_valid_dec    : std_logic;
    
    -- enc/dec output muxing
    signal data_block_out   : std_logic_vector(127 downto 0);
    signal output_valid     : std_logic;
    signal output_valid_enc : std_logic;
    signal output_valid_dec : std_logic;
begin

    -- Implement the interface in "doc/external_interface.md"
    mode_sel_proc : process(clk)
    begin
        if rising_edge(clk) then 
            if reset = '1' then
                mode_sel_sr <= (others => '0');
                mode <= '0'; -- encryption
            else
                mode_sel_sr <= mode_sel_sr(mode_sel_sr'high-1 downto 0) & (start and send_auth);
                if mode_sel_sr = "11111" and interface_state = read_iv then
                    -- don't switch modes unless we've just reset
                    mode <= '1'; -- decryption
                end if;
            end if;
        end if; -- clk
    end process;

    interface_proc : process(clk)
        variable shift_cnt : integer;
    begin
        if rising_edge(clk) then
            done <= '0'; -- Clear pulse
            input_key_valid <= '0';
            init_vec_valid  <= '0';
            input_valid     <= '0';
            if reset = '1' then
                shift_cnt := 0;
                interface_state <= read_iv;
            else
                case interface_state is
                    -------------------------------
                    when read_iv =>
                    -- Don't read bus if we're potentially switching enc/dec
                        first_block <= '1';
                        if start = '1' and send_auth /= '1' then
                            init_vec <= init_vec(95 downto 0) & data_bus; -- Shift left x32
                            shift_cnt := shift_cnt + 1;
                            done <= '1'; -- Pulsed
                            if shift_cnt = 4 then
                                init_vec_valid <= '1'; -- Pulsed
                                interface_state <= read_key;
                                shift_cnt := 0;
                            end if;
                        end if;
                    -------------------------------
                    when read_key =>
                        if start = '1' then
                            input_key <= input_key(95 downto 0) & data_bus; -- Shift left x32
                            shift_cnt := shift_cnt + 1;
                            done <= '1'; -- Pulsed
                            if shift_cnt = 4 then
                                interface_state <= read_block;
                                input_key_valid <= '1'; -- Pulsed
                                shift_cnt := 0;
                            end if;
                        end if;
                    -------------------------------
                    when read_block =>
                        if start = '1' then
                            data_block_in <= data_block_in(95 downto 0) & data_bus; -- Shift left x32
                            shift_cnt := shift_cnt + 1;
                            done <= '1'; -- Pulsed
                            if shift_cnt = 4 then
                                input_valid <= '1'; -- Pulsed
                                interface_state <= wait_output;
                                shift_cnt := 0;
                            end if;
                        end if;
                    -------------------------------
                    when wait_output =>
                        if output_valid = '1' then
                            interface_state <= return_datablock;
                        end if;
                    -------------------------------
                    when return_datablock =>
                        first_block <= '0';
                        if send_auth = '1' then
                            -- We are cleared to drive the data bus
                            if start = '1' then
                                -- user has read the data
                                shift_cnt := shift_cnt + 1;
                            end if;
                            
                            if shift_cnt = 4 then
                                shift_cnt := 0;
                                interface_state <= read_block;
                            else
                                data_bus <= data_block_out(127 - shift_cnt*32 downto 96 - shift_cnt*32); -- data
                                done <= '1'; -- Pulsed
                            end if;
                        end if;
                    -------------------------------
                    when others => null;
                    -------------------------------
                end case;
            end if; -- reset
        end if; -- clk
    end process;

    key_expansion_inst : entity work.key_expansion(rtl)
    port map
    (
        -- Common
        clk             => clk,              -- in std_logic;
        reset           => reset,            -- in std_logic;
        -- Input
        key             => input_key,        -- in std_logic_vector(127 downto 0);
        input_en        => input_key_valid,  -- in std_logic;
        -- Output
        e_key           => e_key,            -- out exp_key_type;
        expansion_done  => expansion_done    -- out std_logic, pulses when *last* key is ready
    );
    -- enc/dec control signal muxing
    init_vec_valid_enc <= init_vec_valid when mode = '0' else '0';
    init_vec_valid_dec <= init_vec_valid when mode = '1' else '0';

    input_valid_enc    <= input_valid    when mode = '0' else '0';
    -- Need to wait for key expansion to complete on the first block:
    input_valid_dec    <= expansion_done when (mode = '1' and first_block = '1') else 
                          input_valid when mode = '1' else '0'; 

    -- enc/dec output muxing
    data_block_out     <= datablock_enc when mode = '0' else datablock_dec;
    output_valid       <= output_valid_enc when mode = '0' else output_valid_dec;

    aes_128_top_enc_inst : entity work.aes_128_top_enc(rtl)
    generic map
    (
        IBW => 16,
        OBW => 16
    )
    port map
    (
        -- Common
        clk              => clk,                -- in std_logic;
        reset            => reset,              -- in std_logic;
        -- Input
        input_bus        => data_block_in,      -- in std_logic_vector(IBW*8-1 downto 0);
        e_key            => e_key,              -- in exp_key_type;
        init_vec         => init_vec,           -- in std_logic_vector(127 downto 0);
        init_vec_valid   => init_vec_valid_enc, -- in std_logic;
        input_valid      => input_valid_enc,    -- in std_logic;                      
        -- Output
        cipherblock      => datablock_enc,      -- out std_logic_vector(OBW*8-1 downto 0);
        output_valid     => output_valid_enc    -- out std_logic
    );

    aes_128_top_dec_inst : entity work.aes_128_top_dec(rtl)
    generic map
    (
        IBW => 16,
        OBW => 16
    )
    port map
    (
        -- Common
        clk              => clk,                -- in std_logic;
        reset            => reset,              -- in std_logic;
        -- Input
        input_bus        => data_block_in,      -- in std_logic_vector(IBW*8-1 downto 0);
        e_key            => e_key,              -- in exp_key_type;
        init_vec         => init_vec,           -- in std_logic_vector(127 downto 0);
        init_vec_valid   => init_vec_valid_dec, -- in std_logic;
        input_valid      => input_valid_dec,    -- in std_logic;                      
        -- Output
        plaintext        => datablock_dec,      -- out std_logic_vector(OBW*8-1 downto 0);
        output_valid     => output_valid_dec    -- out std_logic
    );

end architecture rtl;
