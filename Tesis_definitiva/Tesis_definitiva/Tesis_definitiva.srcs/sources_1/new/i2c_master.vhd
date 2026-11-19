
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  generic (
    CLK_FREQ_HZ : integer := 125000000;
    I2C_SCL_HZ  : integer := 100000
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    start      : in std_logic;
    slave_addr : in std_logic_vector(6 downto 0);
    rw         : in std_logic;

    dato1        : in std_logic_vector(7 downto 0);
    dato2        : in std_logic_vector(7 downto 0);
    cuenta_datos : in unsigned(1 downto 0);

    rx_data : out std_logic_vector(7 downto 0);

    sda_i : in  std_logic;
    sda_t : out std_logic;
    SCL   : out std_logic;

    busy      : out std_logic;
    done      : out std_logic;
    ack_error : out std_logic
  );
end entity;

architecture rtl of i2c_master is

  constant TICK_DIVIDER : integer := CLK_FREQ_HZ / (I2C_SCL_HZ * 2);
  constant DIV_MAX      : integer := TICK_DIVIDER - 1;

  type state_t is (
    IDLE,
    START_SDA_LOW,
    START_SCL_LOW,
    PREPARAR_DATO_LOW,
    ENVIAR_BIT_HIGH,
    ACK_LOW,
    ACK_HIGH,
    LEER_BIT_LOW,
    LEER_BIT_HIGH,
    LEER_NACK_LOW,
    LEER_NACK_HIGH,
    STOP_SCL_LOW,
    STOP_SDA_LOW,
    STOP_SCL_HIGH,
    STOP_LIBERAR,
    ESPERAR_LIBERAR_START
  );

  type fase_t is (
    FASE_DIRECCION,
    FASE_DATO1,
    FASE_DATO2,
    FASE_LECTURA
  );

  signal state : state_t := IDLE;
  signal fase  : fase_t  := FASE_DIRECCION;

  signal cuenta_tick : integer range 0 to DIV_MAX := 0;

  signal scl_registro : std_logic := '1';
  signal bajar_sda    : std_logic := '0';

  signal busy_registro      : std_logic := '0';
  signal done_registro      : std_logic := '0';
  signal ack_error_registro : std_logic := '0';

  signal rw_registro : std_logic := '0';

  signal cuenta_datos_registro : unsigned(1 downto 0) := (others => '0');

  signal dato_actual_registro : std_logic_vector(7 downto 0) := (others => '0');

  signal dato_recibido_registro : std_logic_vector(7 downto 0) := (others => '0');

  signal indice_bit : integer range 0 to 7 := 7;

begin

  SCL <= scl_registro;

  sda_t <= not bajar_sda;

  busy      <= busy_registro;
  done      <= done_registro;
  ack_error <= ack_error_registro;
  rx_data   <= dato_recibido_registro;

  process(clk)
    variable tick_ahora : std_logic;
  begin
    if rising_edge(clk) then

      if rst = '1' then

        state <= IDLE;
        fase  <= FASE_DIRECCION;

        cuenta_tick <= 0;

        scl_registro <= '1';
        bajar_sda    <= '0';

        busy_registro      <= '0';
        done_registro      <= '0';
        ack_error_registro <= '0';

        rw_registro           <= '0';
        cuenta_datos_registro <= (others => '0');

        dato_actual_registro   <= (others => '0');
        dato_recibido_registro <= (others => '0');

        indice_bit <= 7;

      else

        done_registro <= '0';
        tick_ahora := '0';

        if cuenta_tick = DIV_MAX then
          cuenta_tick <= 0;
          tick_ahora := '1';
        else
          cuenta_tick <= cuenta_tick + 1;
        end if;

        if state = IDLE and start = '1' then

          scl_registro <= '1';
          bajar_sda    <= '0';

          busy_registro      <= '1';
          ack_error_registro <= '0';

          rw_registro           <= rw;
          cuenta_datos_registro <= cuenta_datos;

          dato_actual_registro <= slave_addr & rw;
          indice_bit           <= 7;
          fase                 <= FASE_DIRECCION;

          state <= START_SDA_LOW;

        elsif state = ESPERAR_LIBERAR_START and start = '0' then

          scl_registro  <= '1';
          bajar_sda     <= '0';
          busy_registro <= '0';

          state <= IDLE;

        elsif tick_ahora = '1' then

          case state is

            when IDLE =>

              scl_registro  <= '1';
              bajar_sda     <= '0';
              busy_registro <= '0';

              state <= IDLE;

            when START_SDA_LOW =>

              scl_registro <= '1';
              bajar_sda    <= '1';
              state        <= START_SCL_LOW;

            when START_SCL_LOW =>

              scl_registro <= '0';
              bajar_sda    <= '1';
              state        <= PREPARAR_DATO_LOW;

            when PREPARAR_DATO_LOW =>

              scl_registro <= '0';

              if dato_actual_registro(indice_bit) = '0' then
                bajar_sda <= '1';
              else
                bajar_sda <= '0';
              end if;

              state <= ENVIAR_BIT_HIGH;

            when ENVIAR_BIT_HIGH =>

              scl_registro <= '1';

              if indice_bit = 0 then
                state <= ACK_LOW;
              else
                indice_bit <= indice_bit - 1;
                state      <= PREPARAR_DATO_LOW;
              end if;

            when ACK_LOW =>

              scl_registro <= '0';
              bajar_sda    <= '0';
              state        <= ACK_HIGH;

            when ACK_HIGH =>

              scl_registro <= '1';

              if sda_i = '1' then

                ack_error_registro <= '1';
                state              <= STOP_SCL_LOW;

              else

                case fase is

                  when FASE_DIRECCION =>

                    if rw_registro = '1' then

                      fase       <= FASE_LECTURA;
                      indice_bit <= 7;
                      state      <= LEER_BIT_LOW;

                    else

                      if cuenta_datos_registro = to_unsigned(1, 2) or
                         cuenta_datos_registro = to_unsigned(2, 2) then

                        dato_actual_registro <= dato1;
                        indice_bit           <= 7;
                        fase                 <= FASE_DATO1;
                        state                <= PREPARAR_DATO_LOW;

                      else

                        ack_error_registro <= '1';
                        state              <= STOP_SCL_LOW;

                      end if;
                    end if;

                  when FASE_DATO1 =>

                    if cuenta_datos_registro = to_unsigned(2, 2) then

                      dato_actual_registro <= dato2;
                      indice_bit           <= 7;
                      fase                 <= FASE_DATO2;
                      state                <= PREPARAR_DATO_LOW;

                    else

                      state <= STOP_SCL_LOW;

                    end if;

                  when FASE_DATO2 =>

                    state <= STOP_SCL_LOW;

                  when others =>

                    state <= STOP_SCL_LOW;

                end case;
              end if;

            when LEER_BIT_LOW =>

              scl_registro <= '0';
              bajar_sda    <= '0';
              state        <= LEER_BIT_HIGH;

            when LEER_BIT_HIGH =>

              scl_registro <= '1';

              dato_recibido_registro(indice_bit) <= sda_i;

              if indice_bit = 0 then

                state <= LEER_NACK_LOW;

              else

                indice_bit <= indice_bit - 1;
                state      <= LEER_BIT_LOW;

              end if;

            when LEER_NACK_LOW =>

              scl_registro <= '0';
              bajar_sda    <= '0';
              state        <= LEER_NACK_HIGH;

            when LEER_NACK_HIGH =>

              scl_registro <= '1';
              bajar_sda    <= '0';
              state        <= STOP_SCL_LOW;

            when STOP_SCL_LOW =>

              scl_registro <= '0';
              state        <= STOP_SDA_LOW;

            when STOP_SDA_LOW =>

              scl_registro <= '0';
              bajar_sda    <= '1';
              state        <= STOP_SCL_HIGH;

            when STOP_SCL_HIGH =>

              scl_registro <= '1';
              bajar_sda    <= '1';
              state        <= STOP_LIBERAR;

            when STOP_LIBERAR =>

              scl_registro <= '1';
              bajar_sda    <= '0';

              busy_registro <= '0';
              done_registro <= '1';

              state <= ESPERAR_LIBERAR_START;

            when ESPERAR_LIBERAR_START =>

              scl_registro  <= '1';
              bajar_sda     <= '0';
              busy_registro <= '0';

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

    end if;
  end process;

end architecture;
