library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_controller is
    port(
        clk        : in  std_logic;                    -- Clock de 50 MHz da Spartan-3A
        rst        : in  std_logic;                    -- Reset geral
        char_in    : in  std_logic_vector(7 downto 0); -- A letra cifrada (pronta para imprimir)
        write_en   : in  std_logic;                    -- Pulso (1 clock) mandando escrever
        busy       : out std_logic;                    -- Avisa o sistema: "Estou ocupado, n�o mande letras agora"
        
        -- Pinos f�sicos ligados ao display LCD da placa
        lcd_rs     : out std_logic;                    -- Register Select (0 = Comando, 1 = Dado)
        lcd_rw     : out std_logic;                    -- Read/Write (Sempre 0 para escrita)
        lcd_e      : out std_logic;                    -- Enable (Pulso para o display gravar o dado)
        lcd_data   : out std_logic_vector(3 downto 0)  -- Barramento de dados (4 bits)
    );
end lcd_controller;

architecture behavioral of lcd_controller is

    -- M�quina de estados principal do LCD
    type state_type is (
        POWER_UP,       -- Espera inicial obrigat�ria ao ligar a placa
        INITIALIZE,     -- Configura o display para modo de 4 bits e limpa a tela
        READY,          -- Tela pronta, esperando o 'write_en'
        SEND_HIGH_NIB,  -- Envia os 4 bits mais significativos da letra
        WAIT_HIGH,      -- Aguarda o display processar a primeira metade
        SEND_LOW_NIB,   -- Envia os 4 bits menos significativos da letra
        WAIT_LOW        -- Aguarda o display processar a segunda metade
    );
    signal state : state_type := POWER_UP;

    -- Temporizador (Contador para os delays em microsegundos e milisegundos)
    -- 50 MHz = 50.000.000 de ciclos por segundo
    signal delay_cnt : integer range 0 to 2_000_000 := 0; 
    
    -- Registrador para segurar a letra enquanto ela � enviada em duas metades
    signal data_reg  : std_logic_vector(7 downto 0) := x"00";
    
    -- Sub-estados para a rotina longa de inicializa��o do HD44780
    signal init_step : integer range 0 to 11 := 0;

begin

    -- O pino Read/Write sempre fica em 0 porque s� vamos escrever na tela
    lcd_rw <= '0';

    process(clk, rst)
    begin
        if rst = '1' then
            state     <= POWER_UP;
            delay_cnt <= 0;
            init_step <= 0;
            busy      <= '1';
            lcd_rs    <= '0';
            lcd_e     <= '0';
            lcd_data  <= "0000";
            
        elsif rising_edge(clk) then
            case state is
            
                -- ==========================================================
                -- 1. WAIT POWER UP: O display precisa de tempo ao ser ligado
                -- ==========================================================
                when POWER_UP =>
                    busy <= '1';
                    if delay_cnt < 1_000_000 then -- Delay de 20ms a 50MHz
                        delay_cnt <= delay_cnt + 1;
                    else
                        delay_cnt <= 0;
                        state <= INITIALIZE;
                    end if;

                -- ==========================================================
                -- 2. SEQU�NCIA DE INICIALIZA��O (Modo 4-bits)
                -- ==========================================================
                when INITIALIZE =>
                    busy <= '1';
                    lcd_rs <= '0'; -- Enviando comandos, n�o letras
                    
                    if delay_cnt = 0 then
                        lcd_e <= '1'; -- Sobe o pino Enable
                        
                        case init_step is
                            when 0 => lcd_data <= "0011"; -- Comando init 1
                            when 1 => lcd_data <= "0011"; -- Comando init 2
                            when 2 => lcd_data <= "0011"; -- Comando init 3
                            when 3 => lcd_data <= "0010"; -- Muda para 4-bits
                            when 4 => lcd_data <= "0010"; -- Configura linhas/fonte (High)
                            when 5 => lcd_data <= "1000"; -- Configura linhas/fonte (Low)
                            when 6 => lcd_data <= "0000"; -- Display OFF (High)
                            when 7 => lcd_data <= "1000"; -- Display OFF (Low)
                            when 8 => lcd_data <= "0000"; -- Clear Display (High)
                            when 9 => lcd_data <= "0001"; -- Clear Display (Low)
                            when 10 => lcd_data <= "0000"; -- Display ON (High)
                            when 11 => lcd_data <= "1111"; -- Display ON, Curso Blink (Low)
                            when others => null;
                        end case;
                        delay_cnt <= delay_cnt + 1;
                        
                    elsif delay_cnt < 50 then -- Mant�m Enable em '1' por 1us
                        delay_cnt <= delay_cnt + 1;
                    
                    elsif delay_cnt < 100_000 then -- Enable volta pra '0', espera comando processar (~2ms)
                        lcd_e <= '0';
                        delay_cnt <= delay_cnt + 1;
                        
                    else
                        delay_cnt <= 0;
                        if init_step = 11 then
                            state <= READY; -- Inicializa��o completa!
                        else
                            init_step <= init_step + 1;
                        end if;
                    end if;

                -- ==========================================================
                -- 3. ESTADO DE ESPERA: Aguardando o teclado enviar letra
                -- ==========================================================
                when READY =>
                    busy <= '0'; -- Avisa o sistema que pode mandar dado!
                    lcd_e <= '0';
                    
                    if write_en = '1' then
                        busy <= '1';             -- Trava o barramento
                        data_reg <= char_in;     -- Salva a letra cifrada
                        state <= SEND_HIGH_NIB;
                        delay_cnt <= 0;
                    end if;

                -- ==========================================================
                -- 4. ESCREVE DADO (Metade Mais Significativa)
                -- ==========================================================
                when SEND_HIGH_NIB =>
                    lcd_rs <= '1'; -- Estamos enviando um caractere (RS = 1)
                    lcd_data <= data_reg(7 downto 4);
                    
                    if delay_cnt = 0 then
                        lcd_e <= '1';
                        delay_cnt <= delay_cnt + 1;
                    elsif delay_cnt < 50 then
                        delay_cnt <= delay_cnt + 1;
                    else
                        lcd_e <= '0';
                        delay_cnt <= 0;
                        state <= WAIT_HIGH;
                    end if;

                when WAIT_HIGH =>
                    if delay_cnt < 2_500 then -- Delay de 50us entre os nibbles
                        delay_cnt <= delay_cnt + 1;
                    else
                        delay_cnt <= 0;
                        state <= SEND_LOW_NIB;
                    end if;

                -- ==========================================================
                -- 5. ESCREVE DADO (Metade Menos Significativa)
                -- ==========================================================
                when SEND_LOW_NIB =>
                    lcd_data <= data_reg(3 downto 0);
                    
                    if delay_cnt = 0 then
                        lcd_e <= '1';
                        delay_cnt <= delay_cnt + 1;
                    elsif delay_cnt < 50 then
                        delay_cnt <= delay_cnt + 1;
                    else
                        lcd_e <= '0';
                        delay_cnt <= 0;
                        state <= WAIT_LOW;
                    end if;

                when WAIT_LOW =>
                    if delay_cnt < 2_500 then -- Delay de 50us ap�s enviar letra
                        delay_cnt <= delay_cnt + 1;
                    else
                        delay_cnt <= 0;
                        state <= READY; -- Libera para a pr�xima letra!
                    end if;

            end case;
        end if;
    end process;

end behavioral;
