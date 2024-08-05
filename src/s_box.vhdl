library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std_unsigned.all;

entity s_box is
port 
(
    -- Common
    clk         : in std_logic;
    reset       : in std_logic;
    -- Input
    input_byte  : in std_logic_vector(7 downto 0);
    input_en    : in std_logic;
    -- Output
	output_byte : out std_logic_vector(7 downto 0);
    output_en   : out std_logic
);
end s_box;

architecture rtl of s_box is

    type s_box_type is array (0 to 15) of std_logic_vector(127 downto 0);

    signal S_BOX : s_box_type :=(
        (x"637C777BF26B6FC53001672BFED7AB76"),
        (x"CA82C97DFA5947F0ADD4A2AF9CA472C0"),
        (x"B7FD9326363FF7CC34A5E5F171D83115"),
        (x"04C723C31896059A071280E2EB27B275"),
        (x"09832C1A1B6E5AA0523BD6B329E32F84"),
        (x"53D100ED20FCB15B6ACBBE394A4C58CF"),
        (x"D0EFAAFB434D338545F9027F503C9FA8"),
        (x"51A3408F929D38F5BCB6DA2110FFF3D2"),
        (x"CD0C13EC5F974417C4A77E3D645D1973"),
        (x"60814FDC222A908846EEB814DE5E0BDB"),
        (x"E0323A0A4906245CC2D3AC629195E479"),
        (x"E7C8376D8DD54EA96C56F4EA657AAE08"),
        (x"BA78252E1CA6B4C6E8DD741F4BBD8B8A"),
        (x"703EB5664803F60E613557B986C11D9E"),
        (x"E1F8981169D98E949B1E87E9CE5528DF"),
        (x"8CA1890DBFE6426841992D0FB054BB16")
    );
    
    signal inv : std_logic_vector(7 downto 0);
    signal data_ready : std_logic;
begin

    input_proc : process(clk)
    begin
        if rising_edge(clk) then
            data_ready <= '0';
            if reset = '1' then
                null;
            else
                if input_en = '1' then
                    inv <= S_BOX(to_integer(input_byte(7 downto 4)))( to_integer(127 - input_byte(3 downto 0)*8) downto to_integer(120 - input_byte(3 downto 0)*8)  );
                    data_ready <= '1'; -- Pulsed
                end if;
            end if;
        end if;
    end process;

    sbox_proc : process(clk)
    begin
        if rising_edge(clk) then
            output_en <= '0';
            if reset = '1' then
                null;
            elsif data_ready = '1' then
                output_byte(0) <= inv(0) xor inv(4) xor inv(5) xor inv(6) xor inv(7) xor '1';
                output_byte(1) <= inv(0) xor inv(1) xor inv(5) xor inv(6) xor inv(7) xor '1';
                output_byte(2) <= inv(0) xor inv(1) xor inv(2) xor inv(6) xor inv(7) xor '0';
                output_byte(3) <= inv(0) xor inv(1) xor inv(2) xor inv(3) xor inv(7) xor '0';
                output_byte(4) <= inv(0) xor inv(1) xor inv(2) xor inv(3) xor inv(4) xor '0';
                output_byte(5) <= inv(1) xor inv(2) xor inv(3) xor inv(4) xor inv(5) xor '1';
                output_byte(6) <= inv(2) xor inv(3) xor inv(4) xor inv(5) xor inv(6) xor '1';
                output_byte(7) <= inv(3) xor inv(4) xor inv(5) xor inv(6) xor inv(7) xor '0';
                output_en <= '1'; -- Pulsed
            end if;
        end if;
    end process;

end architecture rtl;