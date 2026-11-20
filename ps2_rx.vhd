library IEEE;	
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ps2_rx is
	port (
		clk      : in  std_logic;
		rst      : in  std_logic;
		ps2_clk  : in  std_logic;
		ps2_data : in  std_logic;
		dout     : out std_logic_vector(7 downto 0);
		rx_done  : out std_logic
	);
end ps2_rx;

architecture behavioral of ps2_rx is
	type state_type is (IDLE, D1, D2, D3, D4, D5, D6, D7, D8, RX_PARITY, RX_STOP);
	signal state: state_type := IDLE;
	
	signal clk_filter: std_logic_vector(7 downto 0) := (others => '1');
	signal ps2_clk_clean: std_logic := '1';
	signal data_filter: std_logic_vector(7 downto 0) := (others => '1');
	signal ps2_data_clean: std_logic := '1';
	
	signal fall_edge: std_logic;
	signal shift_reg: std_logic_vector(7 downto 0) := (others => '0');
begin

	process(clk)
	begin
		if rising_edge(clk) then
			clk_filter <= clk_filter(6 downto 0) & ps2_clk;
			if clk_filter = x"FF" then ps2_clk_clean <= '1';
			elsif clk_filter = x"00" then ps2_clk_clean <= '0';
			end if;
			
			data_filter <= data_filter(6 downto 0) & ps2_data;
			if data_filter = x"FF" then ps2_data_clean <= '1';
			elsif data_filter = x"00" then ps2_data_clean <= '0';
			end if;
		end if;
	end process;

	process(clk)
	    variable clk_delay : std_logic := '1';
	begin
	    if rising_edge(clk) then
	        fall_edge <= clk_delay and (not ps2_clk_clean);
	        clk_delay := ps2_clk_clean;
	    end if;
	end process;

	process(clk, rst)
	begin
		if rst = '1' then
			state <= IDLE;
			rx_done <= '0';
		elsif rising_edge(clk) then
		    rx_done <= '0';
		    if fall_edge = '1' then
		        case state is
		            when IDLE =>
		                if ps2_data_clean = '0' then state <= D1; end if;
		            when D1 => shift_reg(0) <= ps2_data_clean; state <= D2;
		            when D2 => shift_reg(1) <= ps2_data_clean; state <= D3;
		            when D3 => shift_reg(2) <= ps2_data_clean; state <= D4;
		            when D4 => shift_reg(3) <= ps2_data_clean; state <= D5;
		            when D5 => shift_reg(4) <= ps2_data_clean; state <= D6;
		            when D6 => shift_reg(5) <= ps2_data_clean; state <= D7;
		            when D7 => shift_reg(6) <= ps2_data_clean; state <= D8;
		            when D8 => shift_reg(7) <= ps2_data_clean; state <= RX_PARITY;
		            when RX_PARITY => state <= RX_STOP;
		            when RX_STOP =>
		                dout <= shift_reg;
		                rx_done <= '1';
		                state <= IDLE;
		        end case;
		    end if;
		end if;
	end process;

end behavioral;