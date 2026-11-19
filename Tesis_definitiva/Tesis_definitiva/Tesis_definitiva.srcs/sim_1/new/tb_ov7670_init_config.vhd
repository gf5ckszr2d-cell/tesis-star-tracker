
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_ov7670_init_config is
end entity;

architecture sim of tb_ov7670_init_config is

    constant CLK_FREQ_HZ    : integer := 125000000;
    constant RESET_DELAY_MS : integer := 1;
    constant PERIODO_CLK    : time := 8 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal start : std_logic := '0';

    signal i2c_done      : std_logic := '0';
    signal i2c_ack_error : std_logic := '0';

    signal i2c_start        : std_logic;
    signal i2c_rw           : std_logic;
    signal i2c_dato1        : std_logic_vector(7 downto 0);
    signal i2c_dato2        : std_logic_vector(7 downto 0);
    signal i2c_cuenta_datos : unsigned(1 downto 0);

    signal busy        : std_logic;
    signal done        : std_logic;
    signal error       : std_logic;
    signal paso_actual : unsigned(4 downto 0);

    -- Valores que esperamos recibir de la ROM

    type par_registro_t is record
        direccion_registro : std_logic_vector(7 downto 0);
        dato               : std_logic_vector(7 downto 0);
    end record;

    type rom_esperada_t is array (0 to 25) of par_registro_t;

    constant ROM_ESPERADA : rom_esperada_t := (

        -- Reinicio
        (x"12", x"80"),

        -- Control de salida
        (x"15", x"00"),
        (x"40", x"C0"),
        (x"13", x"88"),

        -- QVGA 320x240, YUV422
        (x"11", x"01"),
        (x"12", x"00"),
        (x"0C", x"04"),
        (x"3E", x"19"),
        (x"70", x"3A"),
        (x"71", x"35"),
        (x"72", x"11"),
        (x"73", x"F1"),
        (x"A2", x"02"),

        -- Orden de bytes
        (x"3A", x"04"),
        (x"3D", x"99"),

        -- Ventana QVGA
        (x"03", x"00"),
        (x"17", x"15"),
        (x"18", x"03"),
        (x"19", x"03"),
        (x"1A", x"7B"),
        (x"32", x"80"),

        -- Perfil fijo D1-C06
        (x"3B", x"00"),
        (x"04", x"00"),
        (x"10", x"60"),
        (x"07", x"40"),
        (x"00", x"10")
    );

begin

    -- Reloj de 125 MHz
    clk <= not clk after PERIODO_CLK / 2;

    -- Modulo que vamos a probar
    uut : entity work.ov7670_init_config
        generic map (
            CLK_FREQ_HZ    => CLK_FREQ_HZ,
            RESET_DELAY_MS => RESET_DELAY_MS
        )
        port map (
            clk => clk,
            rst => rst,

            start => start,

            i2c_done      => i2c_done,
            i2c_ack_error => i2c_ack_error,

            i2c_start        => i2c_start,
            i2c_rw           => i2c_rw,
            i2c_dato1        => i2c_dato1,
            i2c_dato2        => i2c_dato2,
            i2c_cuenta_datos => i2c_cuenta_datos,

            busy        => busy,
            done        => done,
            error       => error,
            paso_actual => paso_actual
        );

    prueba : process

        variable tiempo_reset : time := 0 ns;

    begin

        ------------------------------------------------
        -- PRUEBA 1: CONFIGURACION COMPLETA
        ------------------------------------------------

        -- Reiniciar
        wait for 80 ns;
        wait until falling_edge(clk);
        rst <= '0';

        -- Iniciar configuracion
        wait until falling_edge(clk);
        start <= '1';

        wait until falling_edge(clk);
        start <= '0';

        -- Comprobar los 26 pares de registros
        for numero in 0 to 25 loop

            -- Esperar una solicitud de escritura
            wait until rising_edge(i2c_start);

            assert i2c_dato1 = ROM_ESPERADA(numero).direccion_registro
                report "ERROR: Direccion incorrecta en el paso "
                       & integer'image(numero)
                severity failure;

            assert i2c_dato2 = ROM_ESPERADA(numero).dato
                report "ERROR: Dato incorrecto en el paso "
                       & integer'image(numero)
                severity failure;

            assert i2c_rw = '0'
                report "ERROR: Se esperaba escritura"
                severity failure;

            assert i2c_cuenta_datos = to_unsigned(2, 2)
                report "ERROR: La cantidad de datos no es 2"
                severity failure;

            assert paso_actual = to_unsigned(numero, 5)
                report "ERROR: Indice de configuracion incorrecto"
                severity failure;

            assert busy = '1'
                report "ERROR: busy no esta activo"
                severity failure;

            -- El segundo par debe esperar al RESET
            if numero = 1 then

                assert now - tiempo_reset >= 1 ms
                    report "ERROR: No se respeto la espera de RESET"
                    severity failure;

                report "Espera de RESET correcta";

            end if;

            report "Par correcto: "
                   & integer'image(numero);

            -- Comprobar que i2c_start sea un pulso
            wait until rising_edge(clk);
            wait for 1 ns;

            assert i2c_start = '0'
                report "ERROR: i2c_start dura mas de un ciclo"
                severity failure;

            -- Simular el tiempo de trabajo del I2C
            for i in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;

            -- Simular escritura terminada sin error
            i2c_ack_error <= '0';
            i2c_done      <= '1';

            if numero = 0 then
                tiempo_reset := now;
            end if;

            wait until rising_edge(clk);
            i2c_done <= '0';

        end loop;

        -- Esperar fin de la configuracion
        wait until done = '1' for 1 us;

        assert done = '1'
            report "ERROR: No termino la configuracion"
            severity failure;

        assert error = '0'
            report "ERROR: Se activo error sin motivo"
            severity failure;

        assert busy = '0'
            report "ERROR: busy sigue activo"
            severity failure;

        report "PRUEBA 1 CORRECTA: 26 pares enviados";

        ------------------------------------------------
        -- PRUEBA 2: SIMULAR UN ERROR DE ACK
        ------------------------------------------------

        -- Esperar a que el modulo vuelva a IDLE
        wait for 10 * PERIODO_CLK;

        -- Iniciar nuevamente
        wait until falling_edge(clk);
        start <= '1';

        wait until falling_edge(clk);
        start <= '0';

        -- Esperar primera escritura
        wait until rising_edge(i2c_start);

        assert paso_actual = to_unsigned(0, 5)
            report "ERROR: No reinicio el indice"
            severity failure;

        assert i2c_dato1 = x"12" and i2c_dato2 = x"80"
            report "ERROR: Primera escritura incorrecta"
            severity failure;

        -- Simular que el I2C detecta un NACK
        for i in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;

        i2c_ack_error <= '1';
        i2c_done      <= '1';

        wait until rising_edge(clk);
        i2c_done      <= '0';
        i2c_ack_error <= '0';

        -- Esperar que el modulo indique error
        wait until error = '1' for 1 us;

        assert error = '1'
            report "ERROR: No se detecto el NACK"
            severity failure;

        assert done = '0'
            report "ERROR: done se activo tras un fallo"
            severity failure;

        assert busy = '0'
            report "ERROR: busy sigue activo tras el fallo"
            severity failure;

        report "PRUEBA 2 CORRECTA: Error detectado";

        report "TODAS LAS PRUEBAS TERMINARON CORRECTAMENTE";

        finish;

    end process;

end architecture;