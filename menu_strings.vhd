library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package menu_strings is
    type str_array is array (0 to 15) of std_logic_vector(7 downto 0);
    
    -- Mensagem: "Deslocamento:"
    constant STR_SHIFT : str_array := (
        x"44", x"45", x"53", x"4C", x"4F", x"43", x"41", x"4D", 
        x"45", x"4E", x"54", x"4F", x"3A", x"20", x"20", x"20"
    );
    -- Mensagem: "[C]ifrar [D]ecif"
    constant STR_MODE : str_array := (
        x"5B", x"43", x"5D", x"49", x"46", x"52", x"41", x"52", 
        x"20", x"5B", x"44", x"5D", x"45", x"43", x"49", x"46"
    );
end package menu_strings;
