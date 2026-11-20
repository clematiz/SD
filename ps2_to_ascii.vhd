library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity scan_to_ascii is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        scan_code   : in  std_logic_vector(7 downto 0);
        rx_done     : in  std_logic;
        ascii_char  : out std_logic_vector(7 downto 0);
        ascii_ready : out std_logic
    );
end scan_to_ascii;

architecture behavioral of scan_to_ascii is
    type state_type is (WAIT_KEY, WAIT_BREAK);
    signal state      : state_type := WAIT_KEY;
    signal temp_ascii : std_logic_vector(7 downto 0);
begin
    -- Mapeamento PS/2 para ASCII
    with scan_code select
        temp_ascii <= x"41" when x"1C", -- A
                      x"42" when x"32", -- B
                      x"43" when x"21", -- C
                      x"44" when x"23", -- D
                      x"45" when x"24", -- E
                      x"46" when x"2B", -- F
                      x"47" when x"34", -- G
                      x"48" when x"33", -- H
                      x"49" when x"43", -- I
                      x"4A" when x"3B", -- J
                      x"4B" when x"42", -- K
                      x"4C" when x"4B", -- L
                      x"4D" when x"3A", -- M
                      x"4E" when x"31", -- N
                      x"4F" when x"44", -- O
                      x"50" when x"4D", -- P
                      x"51" when x"15", -- Q
                      x"52" when x"2D", -- R
                      x"53" when x"1B", -- S
                      x"54" when x"2C", -- T
                      x"55" when x"3C", -- U
                      x"56" when x"2A", -- V
                      x"57" when x"1D", -- W
                      x"58" when x"22", -- X
                      x"59" when x"35", -- Y
                      x"5A" when x"1A", -- Z
                      x"30" when x"45", -- 0
                      x"31" when x"16", -- 1
                      x"32" when x"1E", -- 2
                      x"33" when x"26", -- 3
                      x"34" when x"25", -- 4
                      x"35" when x"2E", -- 5
                      x"36" when x"36", -- 6
                      x"37" when x"3D", -- 7
                      x"38" when x"3E", -- 8
                      x"39" when x"46", -- 9
                      x"20" when x"29", -- Espaço
                      x"08" when x"66", -- Backspace
                      x"0D" when x"5A", -- Enter
                      x"00" when others;

    process(clk, rst)
    begin
        if rst = '1' then
            state       <= WAIT_KEY;
            ascii_ready <= '0';
            ascii_char  <= x"00";
        elsif rising_edge(clk) then
            ascii_ready <= '0';
            
            case state is
                when WAIT_KEY =>
                    if rx_done = '1' then
                        if scan_code = x"F0" then
                            state <= WAIT_BREAK;
                        elsif scan_code = x"E0" then
                            state <= WAIT_KEY;
                        elsif temp_ascii /= x"00" then
                            ascii_char  <= temp_ascii;
                            ascii_ready <= '1';
                        end if;
                    end if;
                when WAIT_BREAK =>
                    if rx_done = '1' then
                        state <= WAIT_KEY;
                    end if;
            end case;
        end if;
    end process;
end behavioral;