library ieee;
use ieee.std_logic_1164.all;
library work;
use work.aes_pkg.all;

entity aes_128_top_enc is
generic
(
    IBW : natural range 1 to 16;  -- Input Bus Width must be power of 2
    OBW : natural range 1 to 16   -- Output Bus Width must be power of 2
);
port 
(
    -- Common
    clk               : in std_logic;
    reset             : in std_logic;
    -- Input
    input_bus         : in std_logic_vector(IBW*8-1 downto 0);
    e_key             : in exp_key_type;
    init_vec          : in std_logic_vector(127 downto 0); -- initial vector to XOR with the plaintext
    init_vec_valid    : in std_logic; 
    -- all inputs must remain valid whenever input_valid is pulsed, even if they're from previous rounds
    input_valid       : in std_logic;                      -- Inlcudes everything: bus, key, init_vec, session_start
    -- Output
	cipherblock       : out std_logic_vector(OBW*8-1 downto 0);
    output_valid      : out std_logic
);
end aes_128_top_enc;

architecture rtl of aes_128_top_enc is
    constant IBW_ROUNDS              : natural := 16/IBW - 1; -- # of ccs required to read in the plaintext
    constant OBW_DELAY               : natural := 16/OBW - 1; -- # of ccs required to output cipherblock
    signal round_key_valid           : std_logic;
    signal plaintext                 : std_logic_vector(127 downto 0);
    signal input_index               : natural range 0 to 16; 
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
        
    signal key_ready                 : std_logic;

    type key_proc_state_type is (idle, start_round, enc_in_prog, end_enc);
    signal rnd_key_state             : key_proc_state_type;
    signal xor_init_vec : std_logic;
    signal xor_init_vec_done : std_logic;
begin
    -- Process for buffering the input plaintext
    cntrl_proc : process(clk)
    variable t_index : integer;
    variable b_index : integer;
    begin
        if rising_edge(clk) then
            input_block_ready <= '0'; --Reset pulse
            xor_init_vec_done <= '0';
            if reset = '1' then
                input_index <= 0;
            else
                if init_vec_valid = '1' then
                    xor_init_vec <= '1';
                elsif xor_init_vec_done = '1' then
                    xor_init_vec <= '0';
                end if;
                if input_valid = '1' or input_index = IBW_ROUNDS + 1 then
                    if input_index = IBW_ROUNDS + 1 then
                        -- we've read in the entire plaintext
                        if xor_init_vec = '1' then
                            -- this will override the previous cipherblock
                            plaintext <= plaintext xor init_vec; -- xor with initial vector
                            input_index <= 0;
                            input_block_ready <= '1'; -- Pulsed
                            xor_init_vec_done <= '1'; -- Pulsed
                        elsif prev_cipherblock_valid = '1' then
                            -- xor with prev cipherblock
                            plaintext <= plaintext xor prev_cipherblock;
                            input_index <= 0;
                            input_block_ready <= '1'; -- Pulsed
                        end if;
                    else
                        -- more to go
                        -- Variables for top and bottom bounds of assigning state array.
                        t_index := 127 - input_index*IBW*8;
                        b_index := 128 - (1 + input_index)*IBW*8;

                        plaintext(t_index downto b_index) <= input_bus;
                        input_index <= input_index + 1;
                    end if;
                end if; -- input valid
            end if; -- reset
        end if; -- clk
    end process;
    
    -- -- Process to add round key
    add_round_key : process(clk)
        variable rnd_num : integer range 0 to 10;
        variable mix_col_out_rdy : std_logic;
    begin
        if rising_edge(clk) then
            s_box_bus_in_valid <= '0'; -- Clear pulses
            output_valid <= '0';
            if reset = '1' then
                rnd_key_state <= idle;
                rnd_num := 0;
                mix_col_out_rdy := '0';
            else
                if input_block_ready = '1' then
                    -- This initiates the encryption round
                    rnd_key_state <= start_round;
                    prev_cipherblock_valid <= '0';
                end if;

                case rnd_key_state is
                    ---------------------------
                    when start_round =>
                        -- In this case we xor with the state array
                        s_box_bus_in <= plaintext xor e_key(0);
                        s_box_bus_in_valid <= '1'; -- Pulsed
                        rnd_key_state <= enc_in_prog;
                        rnd_num := 0;
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