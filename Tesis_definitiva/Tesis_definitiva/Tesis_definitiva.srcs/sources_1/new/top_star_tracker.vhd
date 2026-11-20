library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.attitude_math_pkg.all;

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
    type estados is (
        ESPERAR_RESULTADO, IDENTIFICAR, RESOLVER_ACTITUD, ENVIAR_IMAGEN,
        ENVIAR_CENTROIDES, ENVIAR_MATCHES, ENVIAR_ACTITUD
    );
    signal estado : estados := ESPERAR_RESULTADO;
    signal resultado_listo, liberar_imagen : std_logic;
    signal direccion_lectura : unsigned(16 downto 0);
    signal dato_lectura : std_logic_vector(7 downto 0);
    signal cantidad : integer range 0 to 64;
    signal x, y, area : unsigned(16 downto 0);
    signal intensidad : unsigned(24 downto 0);
    signal overflow : std_logic;
    signal enviar_foto : std_logic := '0';
    signal fin_foto, inicio_lista, fin_lista : std_logic;
    signal inicio_uart_foto, inicio_uart_lista, inicio_uart : std_logic;
    signal dato_uart_foto, dato_uart_lista, dato_uart : std_logic_vector(7 downto 0);
    signal uart_busy, uart_done : std_logic;
    signal indice_det, indice_uart : integer range 0 to 63;
    signal indice_id : unsigned(7 downto 0);
    signal estrella_valida, comenzar_foto, lista_id : std_logic;
    signal fin_id, exito_id, match_valido : std_logic;
    signal cantidad_id, cantidad_matches : unsigned(3 downto 0) := (others => '0');
    signal match_id : unsigned(8 downto 0);
    signal match_indice : unsigned(7 downto 0);
    signal match_rayo : std_logic_vector(47 downto 0);
    signal foto : unsigned(31 downto 0) := (others => '0');
    signal inicio_matches, fin_uart_matches, inicio_uart_matches : std_logic;
    signal dato_uart_matches : std_logic_vector(7 downto 0);
    signal q : vec4_t;
    signal fin_actitud, actitud_valida : std_logic;
    signal inicio_actitud_uart, fin_actitud_uart, inicio_uart_actitud : std_logic;
    signal dato_uart_actitud : std_logic_vector(7 downto 0);
begin
    comenzar_foto <= '1' when estado = ESPERAR_RESULTADO and resultado_listo = '1' else '0';
    lista_id <= '1' when estado = IDENTIFICAR else '0';
    indice_det <= to_integer(indice_id(5 downto 0)) when estado = IDENTIFICAR else indice_uart;

    inicio_lista <= '1' when estado = ENVIAR_IMAGEN and fin_foto = '1' else '0';
    inicio_matches <= '1' when estado = ENVIAR_CENTROIDES and fin_lista = '1' else '0';
    inicio_actitud_uart <= '1' when estado = ENVIAR_MATCHES and fin_uart_matches = '1' else '0';
    liberar_imagen <= '1' when estado = ENVIAR_ACTITUD and fin_actitud_uart = '1' else '0';

    with estado select inicio_uart <=
        inicio_uart_foto when ENVIAR_IMAGEN,
        inicio_uart_lista when ENVIAR_CENTROIDES,
        inicio_uart_matches when ENVIAR_MATCHES,
        inicio_uart_actitud when ENVIAR_ACTITUD,
        '0' when others;
    with estado select dato_uart <=
        dato_uart_foto when ENVIAR_IMAGEN,
        dato_uart_lista when ENVIAR_CENTROIDES,
        dato_uart_matches when ENVIAR_MATCHES,
        dato_uart_actitud when ENVIAR_ACTITUD,
        (others => '0') when others;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                estado <= ESPERAR_RESULTADO;
                enviar_foto <= '0';
                foto <= (others => '0');
                cantidad_matches <= (others => '0');
            else
                case estado is
                    when ESPERAR_RESULTADO =>
                        if comenzar_foto = '1' then
                            foto <= foto + 1;
                            estado <= IDENTIFICAR;
                        end if;
                    when IDENTIFICAR =>
                        if fin_id = '1' then
                            cantidad_matches <= cantidad_id;
                            estado <= RESOLVER_ACTITUD;
                        end if;
                    when RESOLVER_ACTITUD =>
                        if fin_actitud = '1' then
                            enviar_foto <= not enviar_foto;
                            estado <= ENVIAR_IMAGEN;
                        end if;
                    when ENVIAR_IMAGEN =>
                        if fin_foto = '1' then
                            estado <= ENVIAR_CENTROIDES;
                        end if;
                    when ENVIAR_CENTROIDES =>
                        if fin_lista = '1' then
                            estado <= ENVIAR_MATCHES;
                        end if;
                    when ENVIAR_MATCHES =>
                        if fin_uart_matches = '1' then
                            estado <= ENVIAR_ACTITUD;
                        end if;
                    when ENVIAR_ACTITUD =>
                        if fin_actitud_uart = '1' then
                            estado <= ESPERAR_RESULTADO;
                        end if;
                end case;
            end if;
        end if;
    end process;

    u_identificador : entity work.star_identifier
        port map (
            clk => clk, rst => reset, list_ready => lista_id,
            list_overflow => overflow, star_count => to_unsigned(cantidad, 8),
            rd_index => indice_id, rd_valid => estrella_valida,
            rd_x_q8_8 => resize(x, 18), rd_y_q8_8 => resize(y, 18),
            rd_intensity => intensidad, busy => open, done => fin_id,
            success => exito_id, identified_count => cantidad_id,
            match_valid => match_valido, match_star_index => match_indice,
            match_catalog_index => match_id, match_ray => match_rayo
        );

    coincidencias_uart : entity work.enviar_matches_uart
        port map (
            clk => clk, reset => reset, nueva_foto => comenzar_foto,
            match_valido => match_valido, iniciar => inicio_matches,
            indice => match_indice, id => resize(match_id + 1, 8), foto => foto,
            uart_busy => uart_busy, uart_done => uart_done,
            uart_start => inicio_uart_matches, uart_dato => dato_uart_matches,
            fin => fin_uart_matches
        );

    u_actitud : entity work.attitude_triad
        port map (
            clk => clk, rst => reset, frame_start => comenzar_foto,
            match_valid => match_valido, match_ray => match_rayo,
            match_catalog_index => match_id, solve => fin_id,
            identification_ok => exito_id, quaternion => q, busy => open,
            done => fin_actitud, valid => actitud_valida
        );

    actitud_uart : entity work.enviar_actitud_uart
        port map (
            clk => clk, reset => reset, iniciar => inicio_actitud_uart,
            valido => actitud_valida, cantidad => cantidad_matches, foto => foto, q => q,
            uart_busy => uart_busy, uart_done => uart_done, uart_start => inicio_uart_actitud,
            uart_dato => dato_uart_actitud, fin => fin_actitud_uart
        );

    sistema : entity work.top_captura_centroide
        generic map (UMBRAL => UMBRAL)
        port map (
            clk => clk, reset => reset, start => start, scl => scl, sda => sda,
            cam_reset => cam_reset, xclk => xclk, pclk => pclk, vsync => vsync,
            href => href, datos => datos, reloj_listo => reloj_listo,
            busy => busy, done => done, error => error,
            direccion_externa => direccion_lectura, dato_externo => dato_lectura,
            indice_estrella => indice_det, x_estrella => x, y_estrella => y,
            area_estrella => area, intensidad_estrella => intensidad,
            estrella_valida => estrella_valida, resultado_listo => resultado_listo,
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
            overflow => overflow, cantidad => cantidad, indice_estrella => indice_uart,
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
