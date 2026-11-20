library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.menu_strings.all;

entity top_level is
    port (
        clk          : in  std_logic; 
        rst_btn      : in  std_logic; 
        
        ps2_clk_in   : in  std_logic;
        ps2_data_in  : in  std_logic;
        
        lcd_rs       : out std_logic;
        lcd_rw       : out std_logic;
        lcd_e        : out std_logic;
        lcd_data     : out std_logic_vector(3 downto 0);
        sf_ce0       : out std_logic
    );
end top_level;

architecture structural of top_level is
    
    component ps2_rx
        port(clk: in std_logic; rst: in std_logic; ps2_clk: in std_logic; ps2_data: in std_logic; dout: out std_logic_vector(7 downto 0); rx_done: out std_logic);
    end component;

    component scan_to_ascii
        port(clk: in std_logic; rst: in std_logic; scan_code: in std_logic_vector(7 downto 0); rx_done: in std_logic; ascii_char: out std_logic_vector(7 downto 0); ascii_ready: out std_logic);
    end component;
    
    component caesar_cipher
        port (ascii_in: in std_logic_vector(7 downto 0); shift: in std_logic_vector(4 downto 0); mode: in std_logic; ascii_out: out std_logic_vector(7 downto 0));
    end component;

    component lcd_controller
        port(clk: in std_logic; rst: in std_logic; char_in: in std_logic_vector(7 downto 0); write_en: in std_logic; cmd_in: in std_logic; busy: out std_logic; lcd_rs: out std_logic; lcd_rw: out std_logic; lcd_e: out std_logic; lcd_data: out std_logic_vector(3 downto 0));
    end component;

    signal rst : std_logic; 
    signal scan_code_wire : std_logic_vector(7 downto 0);
    signal rx_done_wire, ascii_ready_wire : std_logic;
    signal ascii_char_wire, cipher_out_wire, lcd_char_wire : std_logic_vector(7 downto 0);
    signal lcd_write_en_wire, lcd_cmd_wire, lcd_busy_wire : std_logic;

    -- Sinais FSM da Aplicação
    type app_state_type is (
        PRINT_MENU_SHIFT, WAIT_SHIFT_INPUT, 
        PRINT_MENU_MODE,  WAIT_MODE_INPUT,
        CLEAR_SCREEN_TYPING, TYPING_MODE
    );
    signal app_state : app_state_type := PRINT_MENU_SHIFT;
    
    signal shift_val : unsigned(7 downto 0) := (others => '0'); -- Armazena ate "25"
    signal current_mode : std_logic := '0';
    signal str_idx : integer range 0 to 16 := 0;

begin
    sf_ce0 <= '1'; 
    rst <= rst_btn;

    MOD_1_RX: ps2_rx port map (clk=>clk, rst=>rst, ps2_clk=>ps2_clk_in, ps2_data=>ps2_data_in, rx_done=>rx_done_wire, dout=>scan_code_wire);
    MOD_2_ASC: scan_to_ascii port map (clk=>clk, rst=>rst, scan_code=>scan_code_wire, rx_done=>rx_done_wire, ascii_char=>ascii_char_wire, ascii_ready=>ascii_ready_wire);
    MOD_3_CIP: caesar_cipher port map (ascii_in=>ascii_char_wire, shift=>std_logic_vector(shift_val(4 downto 0)), mode=>current_mode, ascii_out=>cipher_out_wire);
    MOD_4_LCD: lcd_controller port map (clk=>clk, rst=>rst, char_in=>lcd_char_wire, write_en=>lcd_write_en_wire, cmd_in=>lcd_cmd_wire, busy=>lcd_busy_wire, lcd_rs=>lcd_rs, lcd_rw=>lcd_rw, lcd_e=>lcd_e, lcd_data=>lcd_data);

    -- Máquina de Estados Principal
    process(clk, rst)
    begin
        if rst = '1' then
            app_state <= PRINT_MENU_SHIFT;
            lcd_write_en_wire <= '0';
            lcd_cmd_wire <= '0';
            shift_val <= (others => '0');
            str_idx <= 0;
        elsif rising_edge(clk) then
            lcd_write_en_wire <= '0';
            lcd_cmd_wire <= '0';

            case app_state is
                -- Fase 1: Pergunta o Deslocamento
                when PRINT_MENU_SHIFT =>
                    if lcd_busy_wire = '0' then
                        if str_idx = 0 then
                            lcd_char_wire <= x"01"; lcd_cmd_wire <= '1'; lcd_write_en_wire <= '1'; str_idx <= 1; -- Clear tela
                        elsif str_idx <= 16 then
                            lcd_char_wire <= STR_SHIFT(str_idx - 1); lcd_write_en_wire <= '1'; str_idx <= str_idx + 1;
                        else
                            str_idx <= 0; app_state <= WAIT_SHIFT_INPUT;
                        end if;
                    end if;

                -- Aguarda digitação (Dezenas e unidades). Encerra com Enter (0x0D).
                when WAIT_SHIFT_INPUT =>
                    if ascii_ready_wire = '1' and lcd_busy_wire = '0' then
                        if ascii_char_wire = x"0D" then -- ENTER apertado
                            app_state <= PRINT_MENU_MODE;
                            str_idx <= 0;
                        elsif ascii_char_wire >= x"30" and ascii_char_wire <= x"39" then -- É um número
                            -- Atualiza o valor: valor = valor * 10 + numero_digitado
                            shift_val <= resize((shift_val * 10) + (unsigned(ascii_char_wire) - x"30"), 8);
                            -- Mostra no display
                            lcd_char_wire <= ascii_char_wire; lcd_write_en_wire <= '1'; 
                        end if;
                    end if;

                -- Fase 2: Pergunta o Modo
                when PRINT_MENU_MODE =>
                    if lcd_busy_wire = '0' then
                        if str_idx = 0 then
                            lcd_char_wire <= x"01"; lcd_cmd_wire <= '1'; lcd_write_en_wire <= '1'; str_idx <= 1;
                        elsif str_idx <= 16 then
                            lcd_char_wire <= STR_MODE(str_idx - 1); lcd_write_en_wire <= '1'; str_idx <= str_idx + 1;
                        else
                            app_state <= WAIT_MODE_INPUT;
                        end if;
                    end if;

                -- Aguarda C ou D
                when WAIT_MODE_INPUT =>
                    if ascii_ready_wire = '1' then
                        if ascii_char_wire = x"43" then     -- Apertou 'C' (Cifrar)
                            current_mode <= '0';
                            app_state <= CLEAR_SCREEN_TYPING;
                        elsif ascii_char_wire = x"44" then  -- Apertou 'D' (Decifrar)
                            current_mode <= '1';
                            app_state <= CLEAR_SCREEN_TYPING;
                        end if;
                    end if;

                -- Limpa a tela para começar a digitar a mensagem final
                when CLEAR_SCREEN_TYPING =>
                    if lcd_busy_wire = '0' then
                        lcd_char_wire <= x"01"; lcd_cmd_wire <= '1'; lcd_write_en_wire <= '1';
                        app_state <= TYPING_MODE;
                    end if;

                -- Fase 3: Digitação Livre cifrando em tempo real
                when TYPING_MODE =>
                    if ascii_ready_wire = '1' and lcd_busy_wire = '0' then
                        -- Se for backspace (0x08) ou Espaço (0x20), manda como está. Senão, manda cifrado.
                        if ascii_char_wire = x"08" then
                            lcd_char_wire <= x"08";
                        else
                            lcd_char_wire <= cipher_out_wire;
                        end if;
                        lcd_write_en_wire <= '1';
                    end if;

            end case;
        end if;
    end process;

end structural;