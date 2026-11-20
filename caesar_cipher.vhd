library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity caesar_cipher is
    port (
        char_in  : in  std_logic_vector(7 downto 0); -- Letra original em ASCII
        char_out : out std_logic_vector(7 downto 0)  -- Letra cifrada (+3) em ASCII
    );
end caesar_cipher;

architecture behavioral of caesar_cipher is
begin
    process(char_in)
    begin
        case char_in is
            -- Letras de A a W (soma 3 normal)
            when x"41" => char_out <= x"44"; -- A -> D
            when x"42" => char_out <= x"45"; -- B -> E
            when x"43" => char_out <= x"46"; -- C -> F
            when x"44" => char_out <= x"47"; -- D -> G
            when x"45" => char_out <= x"48"; -- E -> H
            when x"46" => char_out <= x"49"; -- F -> I
            when x"47" => char_out <= x"4A"; -- G -> J
            when x"48" => char_out <= x"4B"; -- H -> K
            when x"49" => char_out <= x"4C"; -- I -> L
            when x"4A" => char_out <= x"4D"; -- J -> M
            when x"4B" => char_out <= x"4E"; -- K -> N
            when x"4C" => char_out <= x"4F"; -- L -> O
            when x"4D" => char_out <= x"50"; -- M -> P
            when x"4E" => char_out <= x"51"; -- N -> Q
            when x"4F" => char_out <= x"52"; -- O -> R
            when x"50" => char_out <= x"53"; -- P -> S
            when x"51" => char_out <= x"54"; -- Q -> T
            when x"52" => char_out <= x"55"; -- R -> U
            when x"53" => char_out <= x"56"; -- S -> V
            when x"54" => char_out <= x"57"; -- T -> W
            when x"55" => char_out <= x"58"; -- U -> X
            when x"56" => char_out <= x"59"; -- V -> Y
            when x"57" => char_out <= x"5A"; -- W -> Z
            
            -- Letras X, Y, Z (dão a volta para o início)
            when x"58" => char_out <= x"41"; -- X -> A
            when x"59" => char_out <= x"42"; -- Y -> B
            when x"5A" => char_out <= x"43"; -- Z -> C
            
            -- Se por acaso chegar um nulo ou caractere inválido, repassa como está
            when others => char_out <= char_in;
        end case;
    end process;
end behavioral;
