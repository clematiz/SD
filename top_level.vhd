library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_level is
    port (
        -- Entradas da Placa (Botões e Clock)
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Entradas do Teclado PS/2
        ps2_clk  : in  std_logic;
        ps2_data : in  std_logic;
        
        -- Saídas para o Display LCD HD44780
        lcd_rs   : out std_logic;
        lcd_rw   : out std_logic;
        lcd_e    : out std_logic;
        lcd_data : out std_logic_vector(3 downto 0);
        
        -- Pino OBRIGATÓRIO para desativar a StrataFlash
        sf_ce0   : out std_logic
    );
end top_level;

architecture structural of top_level is

    component ps2_rx is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            enable   : in  std_logic;
            ps2_clk  : in  std_logic;
            ps2_data : in  std_logic;
            scancode : out std_logic_vector(7 downto 0);
            is_ready : out std_logic
        );
    end component;

    component scan_to_ascii is
        port(
            clk         : in  std_logic;
            rst         : in  std_logic;
            scan_code   : in  std_logic_vector(7 downto 0);
            rx_done     : in  std_logic;
            ascii_char  : out std_logic_vector(7 downto 0);
            ascii_ready : out std_logic
        );
    end component;

    component caesar_cipher is
        port (
            char_in  : in  std_logic_vector(7 downto 0);
            char_out : out std_logic_vector(7 downto 0)
        );
    end component;

    component lcd_controller is
        port(
            clk        : in  std_logic;
            rst        : in  std_logic;
            char_in    : in  std_logic_vector(7 downto 0);
            write_en   : in  std_logic;
            busy       : out std_logic;
            lcd_rs     : out std_logic;
            lcd_rw     : out std_logic;
            lcd_e      : out std_logic;
            lcd_data   : out std_logic_vector(3 downto 0)
        );
    end component;
    
    signal scancode_wire    : std_logic_vector(7 downto 0);
    signal ps2_ready_wire   : std_logic;
    signal ascii_char_wire  : std_logic_vector(7 downto 0);
    signal ascii_ready_wire : std_logic;
    signal cipher_char_wire : std_logic_vector(7 downto 0);
    signal lcd_busy_wire    : std_logic;
    signal lcd_write_en     : std_logic;

begin

    -- Desativa a memória Flash para liberar o LCD
    sf_ce0 <= '1';

    U1_PS2_RX: ps2_rx
        port map (clk => clk, rst => rst, enable => '1', ps2_clk => ps2_clk, ps2_data => ps2_data, scancode => scancode_wire, is_ready => ps2_ready_wire);

    U2_SCAN_TO_ASCII: scan_to_ascii
        port map (clk => clk, rst => rst, scan_code => scancode_wire, rx_done => ps2_ready_wire, ascii_char => ascii_char_wire, ascii_ready => ascii_ready_wire);

    U3_CAESAR: caesar_cipher
        port map (char_in => ascii_char_wire, char_out => cipher_char_wire);

    U4_LCD: lcd_controller
        port map (clk => clk, rst => rst, char_in => cipher_char_wire, write_en => lcd_write_en, busy => lcd_busy_wire, lcd_rs => lcd_rs, lcd_rw => lcd_rw, lcd_e => lcd_e, lcd_data => lcd_data);
    
    process(clk, rst)
    begin
        if rst = '1' then
            lcd_write_en <= '0';
        elsif rising_edge(clk) then
            if ascii_ready_wire = '1' and lcd_busy_wire = '0' then
                lcd_write_en <= '1'; 
            else
                lcd_write_en <= '0';
            end if;
        end if;
    end process;

end structural;
