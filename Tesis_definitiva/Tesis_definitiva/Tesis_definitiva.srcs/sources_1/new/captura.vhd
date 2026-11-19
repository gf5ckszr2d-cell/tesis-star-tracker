library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity captura is
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

        direccion_lectura   : in unsigned(16 downto 0);
        dato_lectura        : out std_logic_vector(7 downto 0);
        cambio_imagen_lista_clk : out std_logic;
        cambio_fin_lectura  : in std_logic;

        reloj_listo : out std_logic;

        busy  : out std_logic;
        done  : out std_logic;
        error : out std_logic
    );
end entity;

architecture rtl of captura is

    constant FRECUENCIA_CLK : integer := 125000000;

    type estado_control_t is (
        ESPERAR_START,
        ESPERAR_CONFIGURACION,
        ESPERAR_LECTURA
    );

    signal estado_control : estado_control_t := ESPERAR_START;

    signal reinicio_meta : std_logic := '1';
    signal reinicio_pclk : std_logic := '1';

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of reinicio_meta : signal is "TRUE";
    attribute ASYNC_REG of reinicio_pclk : signal is "TRUE";

    signal inicio_configuracion : std_logic := '0';
    signal fin_configuracion    : std_logic;
    signal error_configuracion  : std_logic;

    signal configurada      : std_logic := '0';
    signal configurada_pclk : std_logic;

    signal start_clk      : std_logic;
    signal start_anterior : std_logic := '0';

    signal cambio_captura          : std_logic := '0';
    signal cambio_captura_pclk     : std_logic;
    signal cambio_captura_anterior : std_logic := '0';
    signal orden_captura_pclk      : std_logic := '0';

    signal luminancia             : std_logic_vector(7 downto 0);
    signal pixel_valido           : std_logic;
    signal posicion_x             : unsigned(9 downto 0);
    signal posicion_y             : unsigned(9 downto 0);
    signal imagen_activa          : std_logic;
    signal fin_imagen             : std_logic;
    signal desbordamiento_captura : std_logic;

    signal escribir  : std_logic;
    signal direccion : unsigned(16 downto 0);
    signal dato      : std_logic_vector(7 downto 0);

    signal captura_ocupada         : std_logic;
    signal imagen_lista            : std_logic;
    signal cambio_imagen_lista     : std_logic;
    signal desbordamiento_guardado : std_logic;

    signal fin_lectura_anterior : std_logic := '0';
    signal cambio_fin_lectura_pclk : std_logic;

begin

    cam_reset <= '1';

    done  <= fin_configuracion;
    error <= error_configuracion;

    process(pclk, reset)
    begin
        if reset = '1' then
            reinicio_meta <= '1';
            reinicio_pclk <= '1';
        elsif rising_edge(pclk) then
            reinicio_meta <= '0';
            reinicio_pclk <= reinicio_meta;
        end if;
    end process;

    generador_reloj : entity work.ov7670_xclk_gen
        port map (
            clk    => clk,
            rst    => reset,
            xclk   => xclk,
            locked => reloj_listo
        );

    configurar_camara : entity work.i2c_configuracion
        generic map (
            CLK_FREQ_HZ => FRECUENCIA_CLK
        )
        port map (
            clk   => clk,
            rst   => reset,
            start => inicio_configuracion,

            SCL => SCL,
            SDA => SDA,

            busy        => busy,
            done        => fin_configuracion,
            error       => error_configuracion,
            paso_actual => open
        );

    process(clk)
    begin
        if rising_edge(clk) then
            inicio_configuracion <= '0';
            start_anterior <= start_clk;
            fin_lectura_anterior <= cambio_fin_lectura;

            if reset = '1' then
                estado_control <= ESPERAR_START;
                configurada <= '0';
                inicio_configuracion <= '0';
                start_anterior <= '0';
                fin_lectura_anterior <= '0';
                cambio_captura <= '0';
            else
                case estado_control is
                    when ESPERAR_START =>
                        if start_clk = '1' and start_anterior = '0' then
                            if configurada = '0' then
                                inicio_configuracion <= '1';
                                estado_control <= ESPERAR_CONFIGURACION;
                            else
                                cambio_captura <= not cambio_captura;
                                estado_control <= ESPERAR_LECTURA;
                            end if;
                        end if;
                    when ESPERAR_CONFIGURACION =>
                        if error_configuracion = '1' then
                            estado_control <= ESPERAR_START;
                        elsif fin_configuracion = '1' then
                            configurada <= '1';
                            cambio_captura <= not cambio_captura;
                            estado_control <= ESPERAR_LECTURA;
                        end if;
                    when ESPERAR_LECTURA =>
                        if cambio_fin_lectura /= fin_lectura_anterior then
                            estado_control <= ESPERAR_START;
                        end if;
                end case;
            end if;
        end if;
    end process;

    sincronizar_start : entity work.sincronizador_cdc
        port map (
            clk_destino  => clk,
            reset        => reset,
            dato_entrada => start,
            dato_salida  => start_clk
        );

    sincronizar_configurada : entity work.sincronizador_cdc
        port map (
            clk_destino  => pclk,
            reset        => reinicio_pclk,
            dato_entrada => configurada,
            dato_salida  => configurada_pclk
        );

    sincronizar_orden_captura : entity work.sincronizador_cdc
        port map (
            clk_destino  => pclk,
            reset        => reinicio_pclk,
            dato_entrada => cambio_captura,
            dato_salida  => cambio_captura_pclk
        );

    process(pclk)
    begin
        if rising_edge(pclk) then
            orden_captura_pclk <= '0';
            if reinicio_pclk = '1' then
                cambio_captura_anterior <= '0';
            else
                cambio_captura_anterior <= cambio_captura_pclk;
                if cambio_captura_pclk /= cambio_captura_anterior then
                    orden_captura_pclk <= '1';
                end if;
            end if;
        end if;
    end process;

    sincronizar_imagen_lista : entity work.sincronizador_cdc
        port map (
            clk_destino  => clk,
            reset        => reset,
            dato_entrada => cambio_imagen_lista,
            dato_salida  => cambio_imagen_lista_clk
        );

    sincronizar_fin_envio : entity work.sincronizador_cdc
        port map (
            clk_destino  => pclk,
            reset        => reinicio_pclk,
            dato_entrada => cambio_fin_lectura,
            dato_salida  => cambio_fin_lectura_pclk
        );

    capturar_imagen : entity work.captura_y
        generic map (
            ANCHO_IMAGEN => 320,
            ALTO_IMAGEN  => 240
        )
        port map (
            pclk      => pclk,
            reset     => reinicio_pclk,
            habilitar => configurada_pclk,

            vsync => vsync,
            href  => href,
            datos => datos,

            luminancia     => luminancia,
            pixel_valido   => pixel_valido,
            posicion_x     => posicion_x,
            posicion_y     => posicion_y,
            imagen_activa  => imagen_activa,
            fin_imagen     => fin_imagen,
            desbordamiento => desbordamiento_captura
        );

    guardar_captura : entity work.guardar_imagen
        generic map (
            ANCHO_IMAGEN   => 320,
            ALTO_IMAGEN    => 240,
            BITS_DIRECCION => 17
        )
        port map (
            pclk  => pclk,
            reset => reinicio_pclk,

            iniciar_captura    => orden_captura_pclk,
            cambio_fin_lectura => cambio_fin_lectura_pclk,

            luminancia   => luminancia,
            pixel_valido => pixel_valido,
            posicion_x   => posicion_x,
            posicion_y   => posicion_y,
            fin_imagen   => fin_imagen,

            escribir  => escribir,
            direccion => direccion,
            dato      => dato,

            captura_ocupada     => captura_ocupada,
            imagen_lista        => imagen_lista,
            cambio_imagen_lista => cambio_imagen_lista,
            desbordamiento      => desbordamiento_guardado
        );

    memoria_imagen : entity work.bram_imagen
        generic map (
            BITS_DIRECCION => 17,
            BITS_DATO      => 8,
            TOTAL_PIXELES  => 76800
        )
        port map (
            clk_escritura       => pclk,
            habilitar_escritura => escribir,
            direccion_escritura => direccion,
            dato_escritura      => dato,

            clk_lectura       => clk,
            direccion_lectura => direccion_lectura,
            dato_lectura      => dato_lectura
        );

end architecture;
