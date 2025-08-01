-- © 2025 Ilya Cable <ilya.cable1@gmail.com>
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package aes_pkg is

    type round_const_type is array(0 to 9) of std_logic_vector(31 downto 0);
    constant R_CON : round_const_type := ( 
        x"01000000", x"02000000", x"04000000", x"08000000", x"10000000", x"20000000", x"40000000", x"80000000", x"1B000000", x"36000000");
        
    type int_arr_10 is array(0 to 9) of integer;
    constant L_INDX : int_arr_10 := (4, 8, 12, 16, 20, 24, 28, 32, 36, 40);

    type s_box_type is array (0 to 15) of std_logic_vector(127 downto 0);
    type exp_key_type is array (0 to 10) of std_logic_vector(127 downto 0); -- 11 subkeys for AES-128

    -- TODO: Put this in BRAM
    constant S_BOX : s_box_type := (
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
    
    constant INV_S_BOX : s_box_type := (
        (x"52096AD53036A538BF40A39E81F3D7FB"),
        (x"7CE339829B2FFF87348E4344C4DEE9CB"),
        (x"547B9432A6C2233DEE4C950B42FAC34E"),
        (x"082EA16628D924B2765BA2496D8BD125"),
        (x"72F8F66486689816D4A45CCC5D65B692"),
        (x"6C704850FDEDB9DA5E154657A78D9D84"),
        (x"90D8AB008CBCD30AF7E45805B8B34506"),
        (x"D02C1E8FCA3F0F02C1AFBD0301138A6B"),
        (x"3A9111414F67DCEA97F2CFCEF0B4E673"),
        (x"96AC7422E7AD3585E2F937E81C75DF6E"),
        (x"47F11A711D29C5896FB7620EAA18BE1B"),
        (x"FC563E4BC6D279209ADBC0FE78CD5AF4"),
        (x"1FDDA8338807C731B11210592780EC5F"),
        (x"60517FA919B54A0D2DE57A9F93C99CEF"),
        (x"A0E03B4DAE2AF5B0C8EBBB3C83539961"),
        (x"172B047EBA77D626E169146355210C7D")
    );

    -- Function Declarations:
    -- Function to obtain multiplicative inverse in G(2^8) via S-Box
    function s_box_byte(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Same as prev. but for word
    function s_box_word(word : std_logic_vector(31 downto 0)) return std_logic_vector;
    -- Inverse of s_box_byte
    function inv_s_box_byte(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 2 in Galois Field 2^8
    function mul_g2(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 3 in Galois Field 2^8
    function mul_g3(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 9 in Galois Field 2^8
    function mul_g9(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 0xB in Galois Field 2^8
    function mul_g11(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 0xD in Galois Field 2^8
    function mul_g13(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to multiply a byte by 0xE in Galois Field 2^8
    function mul_g14(byte : std_logic_vector(7 downto 0)) return std_logic_vector;
    -- Function to rotate four bytes (a word) left by one byte (a.k.a. 8x rotate left)
    function rot_word(word : std_logic_vector(31 downto 0)) return std_logic_vector;
    -- Checks index against a LUT
    function is_leftmost(index : integer) return std_logic;

end package aes_pkg;

package body aes_pkg is

    function s_box_byte(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return  S_BOX(to_integer(unsigned(byte(7 downto 4))))(127 - to_integer(unsigned(byte(3 downto 0)))*8
                      downto 120 - to_integer(unsigned(byte(3 downto 0)))*8);
    end s_box_byte;

    function s_box_word(word : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return  s_box_byte(word(31 downto 24)) & s_box_byte(word(23 downto 16)) 
                & s_box_byte(word(15 downto 8)) & s_box_byte(word(7 downto 0));
    end s_box_word;
    
    function inv_s_box_byte(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return  INV_S_BOX(to_integer(unsigned(byte(7 downto 4))))(127 - to_integer(unsigned(byte(3 downto 0)))*8
                      downto 120 - to_integer(unsigned(byte(3 downto 0)))*8);
    end inv_s_box_byte;

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

    function mul_g9(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        -- 9x = 8x + x
        return mul_g2(mul_g2(mul_g2(byte))) xor byte;
    end mul_g9;

    function mul_g11(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        -- 11x = 8x + 2x + x
        return mul_g2(mul_g2(mul_g2(byte))) xor mul_g2(byte) xor byte;
    end mul_g11;

    function mul_g13(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        -- 13x = 8x + 4x + x
        return mul_g2(mul_g2(mul_g2(byte))) xor mul_g2(mul_g2(byte)) xor byte;
    end mul_g13;

    function mul_g14(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        -- 14x = 8x + 4x + 2x
        return mul_g2(mul_g2(mul_g2(byte))) xor mul_g2(mul_g2(byte)) xor mul_g2(byte);
    end mul_g14;

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