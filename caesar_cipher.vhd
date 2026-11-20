library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity caesar_cipher is
	port (
		ascii_in : in  std_logic_vector(7 downto 0); 
		shift: in  std_logic_vector(4 downto 0); 
		mode: in  std_logic;                    -- '0' = Cifrar, '1' = Decifrar
		ascii_out: out std_logic_vector(7 downto 0) 
	);
end caesar_cipher;

architecture behavioral of caesar_cipher is
begin
	process(ascii_in, shift, mode)
		variable idx_in: integer range 0 to 25;
		variable shift_int: integer range 0 to 31;
		variable idx_out: integer range -31 to 63;
	begin
		shift_int := to_integer(unsigned(shift));
		if shift_int > 25 then
			shift_int := shift_int - 26;
		end if;
		
		if unsigned(ascii_in) >= 65 and unsigned(ascii_in) <= 90 then
			idx_in := to_integer(unsigned(ascii_in)) - 65;
			if mode = '0' then
				idx_out := idx_in + shift_int;
				if idx_out >= 26 then idx_out := idx_out - 26; end if;
			else
				idx_out := idx_in - shift_int;
				if idx_out < 0 then idx_out := idx_out + 26; end if;
			end if;
			ascii_out <= std_logic_vector(to_unsigned(idx_out + 65, 8));
		else
			ascii_out <= ascii_in;
		end if;
	end process;
end behavioral;