-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
library ieee;
use ieee.std_logic_1164.all;
use work.aes_pkg.all;

entity aes_128_top_dec is
port 
(
    -- Common
    clk            : in std_logic;
    reset          : in std_logic;
    -- Input
    input_bus      : in std_logic_vector(127 downto 0);
    e_key          : in exp_key_type;
    init_vec       : in std_logic_vector(127 downto 0); -- initial vector to XOR with the cipherblock
    init_vec_valid : in std_logic; 
    input_valid    : in std_logic;
    -- Output
	plaintext      : out std_logic_vector(127 downto 0);
    output_valid   : out std_logic
);
end aes_128_top_dec;

architecture rtl of aes_128_top_dec is
    signal prev_cipherblock          : std_logic_vector(127 downto 0);
    
    signal shift_rows_bus_in         : std_logic_vector(127 downto 0);
    signal shift_rows_bus_in_valid   : std_logic;
    signal shift_rows_bus_out        : std_logic_vector(127 downto 0);
    signal shift_rows_bus_out_valid  : std_logic;

    signal s_box_bus_out             : std_logic_vector(127 downto 0);
    signal s_box_bus_out_valid       : std_logic;
    
    signal mix_columns_bus_in        : std_logic_vector(127 downto 0);
    signal mix_columns_bus_in_valid  : std_logic;
    signal mix_columns_bus_out       : std_logic_vector(127 downto 0);
    signal mix_columns_bus_out_valid : std_logic;
    
    type key_proc_state_type is (idle, dec_in_prog, end_dec);
    signal rnd_key_state             : key_proc_state_type;
    signal xor_init_vec : std_logic;
    signal xor_init_vec_done : std_logic;

    signal plaintext_i : std_logic_vector(127 downto 0);
    signal current_cipherblock : std_logic_vector(127 downto 0);

begin
 
    -- Process to add round key
    add_round_key : process(clk)
        variable rnd_num : integer range 0 to 10;
    begin
        if rising_edge(clk) then
            -- Reset pulses
            output_valid <= '0';
            shift_rows_bus_in_valid <= '0';
            mix_columns_bus_in_valid <= '0';
            xor_init_vec_done <= '0';
            if reset = '1' then
                rnd_key_state <= idle;
                rnd_num := 0;
            else
                -- Control signals for xoring the initial vector
                if init_vec_valid = '1' then
                    xor_init_vec <= '1';
                elsif xor_init_vec_done = '1' then
                    xor_init_vec <= '0';
                end if;

                if input_valid = '1' then
                    -- This initiates the decryption round
                    rnd_key_state           <= dec_in_prog;
                    current_cipherblock     <= input_bus;
                    shift_rows_bus_in       <= input_bus xor e_key(10);
                    shift_rows_bus_in_valid <= '1'; -- Pulsed
                    rnd_key_state           <= dec_in_prog;
                    rnd_num := 0;
                end if;
                case rnd_key_state is
                    ---------------------------
                    when dec_in_prog =>
                        -- In this case xor with the expanded key
                        if mix_columns_bus_out_valid = '1' then
                            shift_rows_bus_in <= mix_columns_bus_out;
                            shift_rows_bus_in_valid <= '1'; -- Pulsed
                        end if;

                        if s_box_bus_out_valid = '1' then
                            if rnd_num = 9 then
                                rnd_key_state <= end_dec;
                                plaintext_i <= s_box_bus_out xor e_key(0);
                            else
                                rnd_num := rnd_num + 1;
                                -- Add round key
                                mix_columns_bus_in <= s_box_bus_out xor e_key(10 - rnd_num);
                                mix_columns_bus_in_valid <= '1'; -- Pulsed
                            end if;
                        end if;
                    --------------------------
                    when end_dec =>
                        if xor_init_vec = '1' then
                            plaintext <= plaintext_i xor init_vec;
                            xor_init_vec_done <= '1'; -- Pulsed
                        else
                            plaintext <= plaintext_i xor prev_cipherblock;
                        end if;
                        prev_cipherblock        <= current_cipherblock;
                        output_valid <= '1'; -- Pulsed
                        rnd_key_state <= idle;
                    ---------------------------
                    when others => null; -- Idle
                    ---------------------------
                end case;
            end if; -- reset
        end if; -- clk
    end process;
    

    inv_shift_rows_inst : entity work.inv_shift_rows(rtl)
    port map
    (
        -- Common
        clk          => clk,                      -- in std_logic;
        reset        => reset,                    -- in std_logic;
        -- Input
        input_bus    => shift_rows_bus_in,            -- in std_logic_vector(NUM_INPUT_BYTES*8 - 1 downto 0);
        input_en     => shift_rows_bus_in_valid,      -- in std_logic;
        -- Output
        output_bus   => shift_rows_bus_out,       -- out std_logic_vector(127 downto 0); -- output is always 16*16 bytes
        output_en    => shift_rows_bus_out_valid  --out std_logic
    );

    inv_s_box_inst : entity work.inv_s_box(rtl)
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
        input_bus   => shift_rows_bus_out,         -- in std_logic_vector(BUS_WIDTH*8-1 downto 0);
        input_en    => shift_rows_bus_out_valid,   -- in std_logic;
        -- Output
        output_bus  => s_box_bus_out,        -- out std_logic_vector(BUS_WIDTH*8-1 downto 0);
        output_en   => s_box_bus_out_valid   -- out std_logic
    );



    inv_mix_columns_inst : entity work.inv_mix_columns(rtl)
    port map
    (
        -- Common
        clk          => clk,                      -- in std_logic;
        reset        => reset,                    -- in std_logic;
        -- Input
        input_bus    => mix_columns_bus_in,       -- in std_logic_vector(127 downto 0);
        input_en     => mix_columns_bus_in_valid, -- in std_logic;
        -- Output
        output_bus   => mix_columns_bus_out,      -- out std_logic_vector(127 downto 0); -- output is always 4*4 bytes
        output_en    => mix_columns_bus_out_valid -- out std_logic
    );

end architecture rtl;