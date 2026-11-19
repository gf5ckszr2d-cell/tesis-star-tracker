library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_star_tracker is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        start : in std_logic;

        SCL : out std_logic;
        SDA : inout std_logic;

        cam_reset : out std_logic;
        xclk      : out std_logic;
        pclk      : in std_logic;

        vsync : in std_logic;
        href  : in std_logic;
        datos : in std_logic_vector(7 downto 0);

        tx : out std_logic;

        reloj_listo : out std_logic;

        busy  : out std_logic;
        done  : out std_logic;
        error : out std_logic
    );
end entity;

architecture rtl of top_star_tracker is
    constant UMBRAL : natural := 45;
    type estados is (ESPERAR_RESULTADO, ENVIAR_IMAGEN, ENVIAR_CENTROIDES);
    signal estado : estados := ESPERAR_RESULTADO;
    signal resultado_listo, liberar_imagen : std_logic;
    signal direccion_lectura : unsigned(16 downto 0);
    signal dato_lectura : std_logic_vector(7 downto 0);
    signal indice : integer range 0 to 63;
    signal cantidad : integer range 0 to 64;
    signal x, y, area : unsigned(16 downto 0);
    signal intensidad : unsigned(24 downto 0);
    signal overflow : std_logic;
    signal enviar_foto : std_logic := '0';
    signal fin_foto, inicio_lista, fin_lista : std_logic;
    signal inicio_uart_foto, inicio_uart_lista, inicio_uart : std_logic;
    signal dato_uart_foto, dato_uart_lista, dato_uart : std_logic_vector(7 downto 0);
    signal uart_busy, uart_done : std_logic;
begin
    inicio_lista <= '1' when estado = ENVIAR_IMAGEN and fin_foto = '1' else '0';
    liberar_imagen <= '1' when estado = ENVIAR_CENTROIDES and fin_lista = '1' else '0';

    inicio_uart <= inicio_uart_lista when estado = ENVIAR_CENTROIDES else inicio_uart_foto;
    dato_uart <= dato_uart_lista when estado = ENVIAR_CENTROIDES else dato_uart_foto;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                estado <= ESPERAR_RESULTADO;
                enviar_foto <= '0';
            else
                case estado is
                    when ESPERAR_RESULTADO =>
                        if resultado_listo = '1' then
                            enviar_foto <= not enviar_foto;
                            estado <= ENVIAR_IMAGEN;
                        end if;
                    when ENVIAR_IMAGEN =>
                        if fin_foto = '1' then
                            estado <= ENVIAR_CENTROIDES;
                        end if;
                    when ENVIAR_CENTROIDES =>
                        if fin_lista = '1' then
                            estado <= ESPERAR_RESULTADO;
                        end if;
                end case;
            end if;
        end if;
    end process;

    sistema : entity work.top_captura_centroide
        generic map (UMBRAL => UMBRAL)
        port map (
            clk => clk, reset => reset, start => start, scl => scl, sda => sda,
            cam_reset => cam_reset, xclk => xclk, pclk => pclk, vsync => vsync,
            href => href, datos => datos, reloj_listo => reloj_listo,
            busy => busy, done => done, error => error,
            direccion_externa => direccion_lectura, dato_externo => dato_lectura,
            indice_estrella => indice, x_estrella => x, y_estrella => y,
            area_estrella => area, intensidad_estrella => intensidad,
            estrella_valida => open, resultado_listo => resultado_listo,
            overflow => overflow, cantidad => cantidad, liberar_imagen => liberar_imagen
        );

    foto_uart : entity work.enviar_imagen_uart
        port map (
            clk => clk, reset => reset, cambio_imagen_lista => enviar_foto,
            direccion_lectura => direccion_lectura, dato_lectura => dato_lectura,
            uart_busy => uart_busy, uart_done => uart_done,
            uart_start => inicio_uart_foto, uart_dato => dato_uart_foto,
            envio_ocupado => open, envio_terminado => fin_foto, cambio_fin_envio => open
        );

    lista_uart : entity work.enviar_centroides_uart
        generic map (UMBRAL => UMBRAL)
        port map (
            clk => clk, reset => reset, start => inicio_lista,
            overflow => overflow, cantidad => cantidad, indice_estrella => indice,
            x_estrella => x, y_estrella => y, area_estrella => area,
            intensidad_estrella => intensidad, uart_busy => uart_busy,
            uart_done => uart_done, uart_start => inicio_uart_lista,
            uart_dato => dato_uart_lista, fin => fin_lista
        );

    salida_uart : entity work.uart_tx
        generic map (FRECUENCIA_CLK => 125000000, BAUD_RATE => 921600)
        port map (
            clk => clk, reset => reset, tx_start => inicio_uart, tx_data => dato_uart,
            tx_line => tx, busy => uart_busy, done => uart_done
        );
end architecture;
