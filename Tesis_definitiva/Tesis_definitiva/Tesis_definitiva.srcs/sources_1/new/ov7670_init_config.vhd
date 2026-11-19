
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ov7670_init_config is
    generic (
        CLK_FREQ_HZ    : integer := 125000000;
        RESET_DELAY_MS : integer := 1
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        i2c_done      : in std_logic;
        i2c_ack_error : in std_logic;

        i2c_start        : out std_logic;
        i2c_rw           : out std_logic;
        i2c_dato1        : out std_logic_vector(7 downto 0);
        i2c_dato2        : out std_logic_vector(7 downto 0);
        i2c_cuenta_datos : out unsigned(1 downto 0);

        busy        : out std_logic;
        done        : out std_logic;
        error       : out std_logic;
        paso_actual : out unsigned(4 downto 0)
    );
end entity;

architecture rtl of ov7670_init_config is

    type state_t is (
        IDLE,
        CARGAR_PAR,
        INICIAR_ESCRITURA,
        ESPERAR_ESCRITURA,
        ESPERAR_RESET,
        SIGUIENTE_PAR,
        FINALIZADO,
        FALLO,
        ESPERAR_LIBERAR_START
    );

    type par_registro_t is record
        direccion_registro : std_logic_vector(7 downto 0);
        dato               : std_logic_vector(7 downto 0);
    end record;

    type rom_config_t is array (natural range <>) of par_registro_t;

    constant CONFIG_ROM : rom_config_t := (

        -- Reinicio del sensor
        (direccion_registro => x"12", dato => x"80"),

        -- Control de salida
        (direccion_registro => x"15", dato => x"00"),
        (direccion_registro => x"40", dato => x"C0"),

        -- COM8: exposicion, ganancia y balance
        -- de blancos automaticos OFF
        (direccion_registro => x"13", dato => x"88"),

        -- QVGA 320x240, YUV422
        (direccion_registro => x"11", dato => x"01"),
        (direccion_registro => x"12", dato => x"00"),
        (direccion_registro => x"0C", dato => x"04"),
        (direccion_registro => x"3E", dato => x"19"),
        (direccion_registro => x"70", dato => x"3A"),
        (direccion_registro => x"71", dato => x"35"),
        (direccion_registro => x"72", dato => x"11"),
        (direccion_registro => x"73", dato => x"F1"),
        (direccion_registro => x"A2", dato => x"02"),

        -- Orden de bytes
        (direccion_registro => x"3A", dato => x"04"),
        (direccion_registro => x"3D", dato => x"99"),

        -- Ventana QVGA y bits altos de ganancia = 0
        (direccion_registro => x"03", dato => x"00"),
        (direccion_registro => x"17", dato => x"15"),
        (direccion_registro => x"18", dato => x"03"),
        (direccion_registro => x"19", dato => x"03"),
        (direccion_registro => x"1A", dato => x"7B"),
        (direccion_registro => x"32", dato => x"80"),

        -- Perfil fijo recuperado de las capturas D1-C06
        (direccion_registro => x"3B", dato => x"00"), -- Extension nocturna OFF
        (direccion_registro => x"04", dato => x"00"), -- Exposicion [1:0]
        (direccion_registro => x"10", dato => x"60"), -- Exposicion [9:2]
        (direccion_registro => x"07", dato => x"40"), -- Exposicion [15:10]
        (direccion_registro => x"00", dato => x"10")  -- Ganancia = 16
    );

    constant TOTAL_PARES : integer := CONFIG_ROM'length;

    constant CICLOS_ESPERA_RESET : integer :=
        (CLK_FREQ_HZ / 1000) * RESET_DELAY_MS;

    signal state : state_t := IDLE;

    signal indice_config : integer range 0 to TOTAL_PARES - 1 := 0;

    signal cuenta_espera : integer range 0 to CICLOS_ESPERA_RESET := 0;

    signal i2c_start_registro : std_logic := '0';
    signal i2c_rw_registro    : std_logic := '0';

    signal i2c_dato1_registro : std_logic_vector(7 downto 0)
                               := (others => '0');

    signal i2c_dato2_registro : std_logic_vector(7 downto 0)
                               := (others => '0');

    signal i2c_cuenta_datos_registro : unsigned(1 downto 0)
                                      := (others => '0');

    signal done_registro  : std_logic := '0';
    signal error_registro : std_logic := '0';

begin

    i2c_start        <= i2c_start_registro;
    i2c_rw           <= i2c_rw_registro;
    i2c_dato1        <= i2c_dato1_registro;
    i2c_dato2        <= i2c_dato2_registro;
    i2c_cuenta_datos <= i2c_cuenta_datos_registro;

    done  <= done_registro;
    error <= error_registro;

    busy <= '1' when state /= IDLE and
                     state /= FINALIZADO and
                     state /= FALLO and
                     state /= ESPERAR_LIBERAR_START else '0';

    paso_actual <= to_unsigned(indice_config, paso_actual'length);

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then

                state <= IDLE;

                indice_config <= 0;
                cuenta_espera <= 0;

                i2c_start_registro <= '0';
                i2c_rw_registro    <= '0';

                i2c_dato1_registro <= (others => '0');
                i2c_dato2_registro <= (others => '0');

                i2c_cuenta_datos_registro <= (others => '0');

                done_registro  <= '0';
                error_registro <= '0';

            else

                i2c_start_registro <= '0';

                case state is

                    when IDLE =>

                        done_registro  <= '0';
                        error_registro <= '0';

                        if start = '1' then

                            indice_config <= 0;
                            cuenta_espera <= 0;
                            state         <= CARGAR_PAR;

                        else

                            state <= IDLE;

                        end if;

                    when CARGAR_PAR =>

                        i2c_rw_registro <= '0';

                        i2c_dato1_registro <=
                            CONFIG_ROM(indice_config).direccion_registro;

                        i2c_dato2_registro <=
                            CONFIG_ROM(indice_config).dato;

                        i2c_cuenta_datos_registro <= to_unsigned(2, 2);

                        state <= INICIAR_ESCRITURA;

                    when INICIAR_ESCRITURA =>

                        i2c_start_registro <= '1';

                        state <= ESPERAR_ESCRITURA;

                    when ESPERAR_ESCRITURA =>

                        if i2c_done = '1' then

                            if i2c_ack_error = '1' then

                                error_registro <= '1';
                                state          <= FALLO;

                            elsif indice_config = 0 then

                                cuenta_espera <= 0;
                                state         <= ESPERAR_RESET;

                            else

                                state <= SIGUIENTE_PAR;

                            end if;

                        else

                            state <= ESPERAR_ESCRITURA;

                        end if;

                    when ESPERAR_RESET =>

                        if cuenta_espera = CICLOS_ESPERA_RESET then

                            state <= SIGUIENTE_PAR;

                        else

                            cuenta_espera <= cuenta_espera + 1;
                            state         <= ESPERAR_RESET;

                        end if;

                    when SIGUIENTE_PAR =>

                        if indice_config = TOTAL_PARES - 1 then

                            done_registro <= '1';
                            state         <= FINALIZADO;

                        else

                            indice_config <= indice_config + 1;
                            state         <= CARGAR_PAR;

                        end if;

                    when FINALIZADO =>

                        done_registro <= '1';
                        state         <= ESPERAR_LIBERAR_START;

                    when FALLO =>

                        error_registro <= '1';
                        state          <= ESPERAR_LIBERAR_START;

                    when ESPERAR_LIBERAR_START =>

                        if start = '0' then

                            state <= IDLE;

                        else

                            state <= ESPERAR_LIBERAR_START;

                        end if;

                    when others =>

                        state <= IDLE;

                end case;

            end if;

        end if;
    end process;

end architecture;
