library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity scan_to_ascii is
    port(
        clk         : in  std_logic;                    -- Clock do sistema
        rst         : in  std_logic;                    -- Reset
        scan_code   : in  std_logic_vector(7 downto 0); -- Código bruto vindo do ps2_rx
        rx_done     : in  std_logic;                    -- Pulso avisando que chegou código novo
        ascii_char  : out std_logic_vector(7 downto 0); -- Letra traduzida (A a Z)
        ascii_ready : out std_logic                     -- Pulso avisando que a letra tá pronta
    );
end scan_to_ascii;

architecture behavioral of scan_to_ascii is

    -- Máquina de estados para lidar com a tecla sendo solta (Break Code = F0)
    type state_type is (IDLE, IGNORE_BREAK);
    signal state : state_type := IDLE;

begin
    process(clk, rst)
    begin
        if rst = '1' then
            state       <= IDLE;
            ascii_char  <= x"00";
            ascii_ready <= '0';
            
        elsif rising_edge(clk) then
            
            -- Por padrão, o aviso de "pronto" fica em '0'.
            -- Ele só vai a '1' por um único ciclo de clock quando acharmos uma letra.
            ascii_ready <= '0'; 

            -- Se o Módulo 1 (ps2_rx) gerou o pulso avisando que tem dado novo...
            if rx_done = '1' then
                
                case state is
                    when IDLE =>
                        if scan_code = x"F0" then
                            -- O teclado mandou F0. Isso significa que a tecla foi solta.
                            -- O próximo código que chegar deve ser ignorado.
                            state <= IGNORE_BREAK;
                        else
                            -- Se não é F0, é uma tecla pressionada! Vamos traduzir:
                            case scan_code is
                                when x"1C" => ascii_char <= x"41"; ascii_ready <= '1'; -- A
                                when x"32" => ascii_char <= x"42"; ascii_ready <= '1'; -- B
                                when x"21" => ascii_char <= x"43"; ascii_ready <= '1'; -- C
                                when x"23" => ascii_char <= x"44"; ascii_ready <= '1'; -- D
                                when x"24" => ascii_char <= x"45"; ascii_ready <= '1'; -- E
                                when x"2B" => ascii_char <= x"46"; ascii_ready <= '1'; -- F
                                when x"34" => ascii_char <= x"47"; ascii_ready <= '1'; -- G
                                when x"33" => ascii_char <= x"48"; ascii_ready <= '1'; -- H
                                when x"43" => ascii_char <= x"49"; ascii_ready <= '1'; -- I
                                when x"3B" => ascii_char <= x"4A"; ascii_ready <= '1'; -- J
                                when x"42" => ascii_char <= x"4B"; ascii_ready <= '1'; -- K
                                when x"4B" => ascii_char <= x"4C"; ascii_ready <= '1'; -- L
                                when x"3A" => ascii_char <= x"4D"; ascii_ready <= '1'; -- M
                                when x"31" => ascii_char <= x"4E"; ascii_ready <= '1'; -- N
                                when x"44" => ascii_char <= x"4F"; ascii_ready <= '1'; -- O
                                when x"4D" => ascii_char <= x"50"; ascii_ready <= '1'; -- P
                                when x"15" => ascii_char <= x"51"; ascii_ready <= '1'; -- Q
                                when x"2D" => ascii_char <= x"52"; ascii_ready <= '1'; -- R
                                when x"1B" => ascii_char <= x"53"; ascii_ready <= '1'; -- S
                                when x"2C" => ascii_char <= x"54"; ascii_ready <= '1'; -- T
                                when x"3C" => ascii_char <= x"55"; ascii_ready <= '1'; -- U
                                when x"2A" => ascii_char <= x"56"; ascii_ready <= '1'; -- V
                                when x"1D" => ascii_char <= x"57"; ascii_ready <= '1'; -- W
                                when x"22" => ascii_char <= x"58"; ascii_ready <= '1'; -- X
                                when x"35" => ascii_char <= x"59"; ascii_ready <= '1'; -- Y
                                when x"1A" => ascii_char <= x"5A"; ascii_ready <= '1'; -- Z
                                
                                -- Ignora números, enter, espaço e outras teclas não cadastradas
                                when others => 
                                    ascii_char  <= x"00"; 
                                    ascii_ready <= '0';
                            end case;
                        end if;
                        
                    when IGNORE_BREAK =>
                        -- A tecla foi solta. O teclado enviou novamente a tecla logo após o F0.
                        -- Não fazemos nada com ela, apenas voltamos ao estado normal (IDLE).
                        state <= IDLE;
                        
                end case;
                
            end if; -- Fim do if rx_done
        end if;
    end process;
end behavioral;
