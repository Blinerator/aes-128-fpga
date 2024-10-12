library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all;

entity aes_128_top_enc is
port 
(
    -- Common
    clk               : in std_logic;
    reset             : in std_logic;
    -- Input
    input_bus         : in std_logic_vector(127 downto 0);
    e_key             : in exp_key_type;
    init_vec          : in std_logic_vector(127 downto 0); -- initial vector to XOR with the plaintext
    init_vec_valid    : in std_logic; 
    -- all inputs must remain valid whenever input_valid is pulsed, even if they're from previous rounds
    input_valid       : in std_logic;                      -- Inlcudes everything: bus, key, init_vec, session_start
    -- Output
	cipherblock       : out std_logic_vector(127 downto 0);
    output_valid      : out std_logic
);
end aes_128_top_enc;

architecture rtl of aes_128_top_enc is
    signal plaintext                 : std_logic_vector(127 downto 0);
    signal input_block_ready         : std_logic;
    
    signal prev_cipherblock          : std_logic_vector(127 downto 0);
    signal prev_cipherblock_valid    : std_logic;
    
    signal s_box_bus_in              : std_logic_vector(127 downto 0);
    signal s_box_bus_in_valid        : std_logic;
    signal s_box_bus_out             : std_logic_vector(127 downto 0);
    signal s_box_bus_out_valid       : std_logic;
    
    signal mix_columns_bus_out       : std_logic_vector(127 downto 0);
    signal mix_columns_bus_out_valid : std_logic;
    
    signal shift_rows_bus_out_valid  : std_logic;
    signal shift_rows_bus_out        : std_logic_vector(127 downto 0);

    type key_proc_state_type is (idle, enc_in_prog, end_enc);
    signal rnd_key_state             : key_proc_state_type;
    signal xor_init_vec : std_logic;
    signal xor_init_vec_done : std_logic;
begin
    
    -- Process to add round key
    add_round_key : process(clk)
        variable rnd_num : integer range 0 to 10;
        variable mix_col_out_rdy : std_logic;
    begin
        if rising_edge(clk) then
            s_box_bus_in_valid <= '0'; -- Clear pulses
            output_valid <= '0';
            input_block_ready <= '0';
            xor_init_vec_done <= '0';
            if reset = '1' then
                rnd_key_state <= idle;
                rnd_num := 0;
                mix_col_out_rdy := '0';
            else
                -- Control signals
                if init_vec_valid = '1' then
                    xor_init_vec <= '1';
                elsif xor_init_vec_done = '1' then
                    xor_init_vec <= '0';
                end if;

                if input_valid = '1' then
                    if xor_init_vec = '1' then
                        -- this will override the previous cipherblock
                        s_box_bus_in <= input_bus xor init_vec xor e_key(0); -- xor with initial vector
                        xor_init_vec_done <= '1'; -- Pulsed
                    elsif prev_cipherblock_valid = '1' then
                        -- xor with prev cipherblock
                        s_box_bus_in <= input_bus xor prev_cipherblock xor e_key(0);
                    end if;
                    -- This initiates the encryption round
                    input_block_ready <= '1'; -- Pulsed
                    prev_cipherblock_valid <= '0';
                    s_box_bus_in_valid <= '1'; -- Pulsed
                    rnd_key_state <= enc_in_prog;
                    rnd_num := 0;
                end if;

                case rnd_key_state is
                    ---------------------------
                    when enc_in_prog =>
                        -- In this case xor with the expanded key
                        if mix_columns_bus_out_valid = '1' then
                            if rnd_num = 8 then
                                rnd_key_state <= end_enc;
                            end if;
                            rnd_num := rnd_num + 1;
                            s_box_bus_in <= mix_columns_bus_out xor e_key(rnd_num);
                            s_box_bus_in_valid <= '1'; -- Pulsed
                        end if;
                    --------------------------
                    when end_enc =>
                        -- Grab the output from shift_rows and xor with final round key
                        if shift_rows_bus_out_valid = '1' then
                            cipherblock <= shift_rows_bus_out xor e_key(10);
                            prev_cipherblock <= shift_rows_bus_out xor e_key(10);
                            output_valid <= '1'; -- Pulsed -- TODO: compile w/ 2008, u can read output ports (cipherblock) instead of using prev_ciph..
                            prev_cipherblock_valid <= '1';
                            rnd_key_state <= idle;
                        end if;
                    ---------------------------
                    when others => null; -- Idle
                    ---------------------------
                end case;
            end if; -- reset
        end if; -- clk
    end process;
    


    s_box_inst : entity work.s_box(rtl)
    generic map
    (
        BUS_WIDTH => 16
    )
    port map
    (
        -- Common
        clk         => clk,                  -- in std_logic;
        reset       => reset,                -- in std_logic;
        -- Input
        input_bus   => s_box_bus_in,         -- in std_logic_vector(BUS_WIDTH*8-1 downto 0);
        input_en    => s_box_bus_in_valid,   -- in std_logic;
        -- Output
        output_bus  => s_box_bus_out,        -- out std_logic_vector(BUS_WIDTH*8-1 downto 0);
        output_en   => s_box_bus_out_valid   -- out std_logic
    );

    shift_rows_inst : entity work.shift_rows(rtl)
    port map
    (
        -- Common
        clk          => clk,                      -- in std_logic;
        reset        => reset,                    -- in std_logic;
        -- Input
        input_bus    => s_box_bus_out,            -- in std_logic_vector(NUM_INPUT_BYTES*8 - 1 downto 0);
        input_en     => s_box_bus_out_valid,      -- in std_logic;
        -- Output
        output_bus   => shift_rows_bus_out,       -- out std_logic_vector(127 downto 0); -- output is always 16*16 bytes
        output_en    => shift_rows_bus_out_valid  --out std_logic
    );

    mix_columns_inst : entity work.mix_columns(rtl)
    port map
    (
        -- Common
        clk          => clk,                      -- in std_logic;
        reset        => reset,                    -- in std_logic;
        -- Input
        input_bus    => shift_rows_bus_out,       -- in std_logic_vector(127 downto 0);
        input_en     => shift_rows_bus_out_valid, -- in std_logic;
        -- Output
        output_bus   => mix_columns_bus_out,      -- out std_logic_vector(127 downto 0); -- output is always 4*4 bytes
        output_en    => mix_columns_bus_out_valid -- out std_logic
    );

end architecture rtl;