library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_controller is
	port (
		clk        : in  std_logic;                    
		rst        : in  std_logic;
		char_in    : in  std_logic_vector(7 downto 0); 
		write_en   : in  std_logic;                    
		cmd_in     : in  std_logic;                    -- '0'=Caractere, '1'=Comando HD44780
		busy       : out std_logic;                    
		lcd_rs     : out std_logic;                    
		lcd_rw     : out std_logic;                    
		lcd_e      : out std_logic;                    
		lcd_data   : out std_logic_vector(3 downto 0)  
	);
end lcd_controller;

architecture behavioral of lcd_controller is

	type state_type is (PWR_UP, INIT_SEQ, CONFIG_CMD, IDLE, SEND_HIGH, PAUSE_NIBBLE, SEND_LOW, WAIT_EXEC);

	signal state_reg, state_next           : state_type := PWR_UP;
	signal timer_reg, timer_next           : unsigned(19 downto 0) := (others => '0');
	signal step_reg, step_next             : unsigned(3 downto 0)  := (others => '0');
	signal char_count_reg, char_count_next : unsigned(5 downto 0)  := (others => '0');
	signal byte_reg, byte_next             : std_logic_vector(7 downto 0) := (others => '0');
	signal rs_reg, rs_next                 : std_logic := '0';
	signal is_init_reg, is_init_next       : std_logic := '1';
	signal bksp_step_reg, bksp_step_next   : unsigned(1 downto 0)  := "00";
	signal lcd_e_reg, lcd_e_next           : std_logic := '0';
	signal lcd_data_reg, lcd_data_next     : std_logic_vector(3 downto 0) := (others => '0');

begin
	process(clk, rst)
	begin
		if rst = '1' then
			state_reg <= PWR_UP; timer_reg <= (others => '0'); step_reg <= (others => '0');
			char_count_reg <= (others => '0'); byte_reg <= (others => '0'); rs_reg <= '0';
			is_init_reg <= '1'; bksp_step_reg <= "00"; lcd_e_reg <= '0'; lcd_data_reg <= (others => '0');
		elsif rising_edge(clk) then
			state_reg <= state_next; timer_reg <= timer_next; step_reg <= step_next;
			char_count_reg <= char_count_next; byte_reg <= byte_next; rs_reg <= rs_next;
			is_init_reg <= is_init_next; bksp_step_reg <= bksp_step_next; lcd_e_reg <= lcd_e_next; lcd_data_reg <= lcd_data_next;
		end if;
	end process;

	process(state_reg, timer_reg, step_reg, char_count_reg, byte_reg, rs_reg, is_init_reg, bksp_step_reg, lcd_e_reg, lcd_data_reg, char_in, write_en, cmd_in)
	begin
		state_next <= state_reg; timer_next <= timer_reg; step_next <= step_reg;
		char_count_next <= char_count_reg; byte_next <= byte_reg; rs_next <= rs_reg;
		is_init_next <= is_init_reg; bksp_step_next <= bksp_step_reg; lcd_e_next <= '0'; lcd_data_next <= lcd_data_reg;
		busy <= '1';

		case state_reg is
			when PWR_UP =>
				rs_next <= '0';
				if timer_reg = 750000 then timer_next <= (others => '0'); step_next <= (others => '0'); state_next <= INIT_SEQ;
				else timer_next <= timer_reg + 1; end if;

			when INIT_SEQ =>
				rs_next <= '0';
				case step_reg is
					when "0000"|"0001"|"0010" => lcd_data_next <= x"3";
					when others => lcd_data_next <= x"2";
				end case;

				if timer_reg < 15 then lcd_e_next <= '1'; else lcd_e_next <= '0'; end if;

				if (step_reg = 0 and timer_reg = 205000) or (step_reg > 0 and timer_reg = 5000) then
					timer_next <= (others => '0');
					if step_reg = 3 then step_next <= (others => '0'); state_next <= CONFIG_CMD; else step_next <= step_reg + 1; end if;
				else timer_next <= timer_reg + 1; end if;

			when CONFIG_CMD =>
				rs_next <= '0'; is_init_next <= '1';
				case step_reg is
					when "0000" => byte_next <= x"28"; 
					when "0001" => byte_next <= x"0E"; 
					when "0010" => byte_next <= x"01"; 
					when others => byte_next <= x"06"; 
				end case;
				timer_next <= (others => '0'); state_next <= SEND_HIGH;

			when IDLE =>
				busy <= '0'; is_init_next <= '0'; bksp_step_next <= "00";

				if write_en = '1' then
					if cmd_in = '1' then
						-- Recebendo comando de limpar tela do top-level
						byte_next <= char_in; rs_next <= '0'; char_count_next <= (others => '0');
						timer_next <= (others => '0'); state_next <= SEND_HIGH;
					elsif char_in = x"08" then
						if char_count_reg > 0 then
							char_count_next <= char_count_reg - 1; rs_next <= '0'; bksp_step_next <= "01";
							if char_count_reg = 16 then byte_next <= x"8F"; else byte_next <= x"10"; end if;
							timer_next <= (others => '0'); state_next <= SEND_HIGH;
						end if;
					elsif char_count_reg < 32 then
						byte_next <= char_in; rs_next <= '1'; char_count_next <= char_count_reg + 1;
						timer_next <= (others => '0'); state_next <= SEND_HIGH;
					end if;
				end if;

			when SEND_HIGH =>
				lcd_data_next <= byte_reg(7 downto 4);
				if timer_reg < 15 then lcd_e_next <= '1'; timer_next <= timer_reg + 1;
				else lcd_e_next <= '0'; timer_next <= (others => '0'); state_next <= PAUSE_NIBBLE; end if;

			when PAUSE_NIBBLE =>
				if timer_reg = 50 then timer_next <= (others => '0'); state_next <= SEND_LOW; else timer_next <= timer_reg + 1; end if;

			when SEND_LOW =>
				lcd_data_next <= byte_reg(3 downto 0);
				if timer_reg < 15 then lcd_e_next <= '1'; timer_next <= timer_reg + 1;
				else lcd_e_next <= '0'; timer_next <= (others => '0'); state_next <= WAIT_EXEC; end if;

			when WAIT_EXEC =>
				if (rs_reg = '0' and byte_reg = x"01" and timer_reg = 82000) or (not (rs_reg = '0' and byte_reg = x"01") and timer_reg = 2000) then
					timer_next <= (others => '0');
					if is_init_reg = '1' then
						if step_reg = 3 then state_next <= IDLE; else step_next <= step_reg + 1; state_next <= CONFIG_CMD; end if;
					elsif bksp_step_reg = "01" then
						byte_next <= x"20"; rs_next <= '1'; bksp_step_next <= "10"; state_next <= SEND_HIGH;
					elsif bksp_step_reg = "10" then
						rs_next <= '0'; bksp_step_next <= "00";
						if char_count_reg = 15 then byte_next <= x"8F"; else byte_next <= x"10"; end if;
						state_next <= SEND_HIGH;
					elsif char_count_reg = 16 and cmd_in = '0' then
						byte_next <= x"C0"; rs_next <= '0'; state_next <= SEND_HIGH; -- Pula linha
					else
						state_next <= IDLE;
					end if;
				else timer_next <= timer_reg + 1; end if;
		end case;
	end process;

	lcd_rs <= rs_reg; lcd_rw <= '0'; lcd_e <= lcd_e_reg; lcd_data <= lcd_data_reg;
end behavioral;