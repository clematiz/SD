library IEEE;	
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ps2_rx is
    port (
        clk      : in  std_logic;                    -- Clock da placa (50 MHz)
        rst      : in  std_logic;                    -- Reset do sistema
        enable   : in  std_logic;                    -- Habilita a leitura
        ps2_clk  : in  std_logic;                    -- Pino de clock que vem do teclado
        ps2_data : in  std_logic;                    -- Pino de dados que vem do teclado
        scancode : out std_logic_vector(7 downto 0); -- O código da tecla que foi apertada
        is_ready : out std_logic                     -- Pulso de 1 clock avisando que a leitura terminou
    );
end ps2_rx;

architecture behavioral of ps2_rx is

    type state_type is (IDLE, RX_DATA, RX_STOP);
    signal current_state, next_state : state_type;
    
    -- Sinais para o filtro (Debouncer) do clock do teclado
    signal filter_reg, filter_next : std_logic_vector(7 downto 0);
    signal f_ps2c_reg, f_ps2c_next : std_logic := '1';
    signal fall_edge               : std_logic;
    
    -- Registradores de deslocamento e contagem
    signal shift_reg, shift_next : std_logic_vector(10 downto 0);
    signal count_reg, count_next : unsigned(3 downto 0);

begin

    -- Registradores do filtro de ruído (Clock do teclado é muito ruidoso)
    process(clk, rst)
    begin
        if rst = '1' then
            filter_reg <= (others => '0');
            f_ps2c_reg <= '0';
        elsif rising_edge(clk) then
            filter_reg <= filter_next;
            f_ps2c_reg <= f_ps2c_next;
        end if;
    end process;

    -- Lógica do filtro: só aceita mudança de nível se o sinal ficar estável por 8 ciclos
    filter_next <= ps2_clk & filter_reg(7 downto 1);
    f_ps2c_next <= '1' when filter_reg = "11111111" else 
                   '0' when filter_reg = "00000000" else 
                   f_ps2c_reg;
                   
    -- Detector de borda de descida (quando o teclado manda ler o bit)
    fall_edge <= f_ps2c_reg and (not f_ps2c_next);

    -- Atualização dos registradores da Máquina de Estados
    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= IDLE;
            shift_reg     <= (others => '0');
            count_reg     <= (others => '0');
        elsif rising_edge(clk) then
            current_state <= next_state;
            shift_reg     <= shift_next;
            count_reg     <= count_next;
        end if;
    end process;

    -- Máquina de Estados (Recebe os 11 bits do pacote PS/2)
    process(current_state, shift_reg, count_reg, fall_edge, enable, ps2_data)
    begin
        -- Valores padrão para evitar latches indesejados
        is_ready   <= '0';
        next_state <= current_state;
        shift_next <= shift_reg;
        count_next <= count_reg;
        
        case current_state is
            when IDLE =>
                -- Se houver borda de descida, estiver habilitado e o bit for '0' (Start Bit)
                if fall_edge = '1' and enable = '1' and ps2_data = '0' then
                    shift_next <= ps2_data & shift_reg(10 downto 1);
                    count_next <= "1001"; -- Faltam 9 bits (8 dados + 1 paridade)
                    next_state <= RX_DATA;
                end if;
                
            when RX_DATA =>
                if fall_edge = '1' then
                    shift_next <= ps2_data & shift_reg(10 downto 1);
                    if count_reg = 0 then
                        next_state <= RX_STOP;
                    else 
                        count_next <= count_reg - 1;
                    end if;
                end if;
                
            when RX_STOP =>
                -- Vai para IDLE no próximo ciclo de clock da FPGA e avisa que terminou
                next_state <= IDLE;
                is_ready   <= '1'; -- Gera o pulso que o módulo 2 vai escutar!
        end case;
    end process;
    
    -- O scancode são os 8 bits do meio (ignorando start bit, paridade e stop bit)
    scancode <= shift_reg(8 downto 1);

end behavioral;
