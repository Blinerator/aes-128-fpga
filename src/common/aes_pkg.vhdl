library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std_unsigned.all;

package aes_pkg is

    type round_const_type is array(0 to 9) of std_logic_vector(31 downto 0);
    constant R_CON : round_const_type := ( 
        x"01000000", x"02000000", x"04000000", x"08000000", x"10000000", x"20000000", x"40000000", x"80000000", x"1B000000", x"36000000");
    -- constant R_CON : std_logic_vector(79 downto 0) := x"01020408102040801B36"; -- TODO: these can be generated with mul_g2
    type int_arr_10 is array(0 to 9) of integer;
    constant L_INDX : int_arr_10 := (4, 8, 12, 16, 20, 24, 28, 32, 36, 40);

    type s_box_type is array (0 to 15) of std_logic_vector(127 downto 0);
    type exp_key_type is array (0 to 10) of std_logic_vector(127 downto 0); -- 11 subkeys for AES-128

    -- TODO: Put this in BRAM, look into T-Box (combining S-Box with mixcols)
    constant S_BOX : s_box_type :=(
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
    
    -- Function Declarations:
    -- Function to obtain multiplicative inverse in G(2^8) via S-Box
    function s_box_byte(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Same as prev. but for word
    function s_box_word(word : std_logic_vector(31 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 2 in Galois Field 2^8
    function mul_g2(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 3 in Galois Field 2^8
    function mul_g3(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to rotate four bytes (a word) left by one byte (a.k.a. 8x rotate left)
    function rot_word(word : std_logic_vector(31 downto 0)) return std_logic_vector;
    -- Checks index against a LUT
    function is_leftmost(index : integer) return std_logic;

end package aes_pkg;

package body aes_pkg is

    function s_box_byte(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return  S_BOX(to_integer(byte(7 downto 4)))( to_integer(127 - byte(3 downto 0)*8) 
                      downto to_integer(120 - byte(3 downto 0)*8)  );
    end s_box_byte;

    function s_box_word(word : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return  s_box_byte(word(31 downto 24)) & s_box_byte(word(23 downto 16)) 
                & s_box_byte(word(15 downto 8)) & s_box_byte(word(7 downto 0));
    end s_box_word;
    
    function mul_g2(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        if byte(7) = '1' then
            return (byte(6 downto 0) & '0') xor x"1B";
        else
            return byte(6 downto 0) & '0'; -- shift left
        end if;
    end mul_g2;

    function mul_g3(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return mul_g2(byte) xor byte; 
    end mul_g3;

    function rot_word(word : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return  word(23 downto 16) & word(15 downto 8) & word(7 downto 0) & word(31 downto 24);
    end rot_word;
    
    function is_leftmost(index : integer) return std_logic is
    begin
        for i in L_INDX'range loop
            if index = L_INDX(i) then
                return '1';
            end if;
        end loop;
        return '0';
    end is_leftmost;
    
end package body aes_pkg;