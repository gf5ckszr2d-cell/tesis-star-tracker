library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  port (
    clk_i2c : in std_logic; -- reloj I2C ya dividido externamente
    rst     : in std_logic;

    -- Control
    start      : in std_logic;
    slave_addr : in std_logic_vector(6 downto 0);
    rw         : in std_logic; -- '0' = escritura, '1' = lectura

    -- Datos de escritura
    tx_byte0 : in std_logic_vector(7 downto 0);
    tx_byte1 : in std_logic_vector(7 downto 0);
    tx_count : in unsigned(1 downto 0); -- 1 o 2 bytes para escritura

    -- Dato de lectura
    rx_data : out std_logic_vector(7 downto 0);

    -- Bus I2C
    SDA : inout std_logic;
    SCL : out std_logic;

    -- Estado
    busy      : out std_logic;
    done      : out std_logic;
    ack_error : out std_logic
  );
end entity;

architecture rtl of i2c_master is

  type state_t is (
    IDLE,
    START_SDA_LOW,
    START_SCL_LOW,

    PREPARE_DATA_LOW,
    SEND_BIT_HIGH,

    ACK_LOW,
    ACK_HIGH,

    READ_BIT_LOW,
    READ_BIT_HIGH,

    READ_NACK_LOW,
    READ_NACK_HIGH,

    STOP_SCL_LOW,
    STOP_SDA_LOW,
    STOP_SCL_HIGH,
    STOP_RELEASE,

    WAIT_START_RELEASE
  );

  type phase_t is (
    PHASE_ADDR,
    PHASE_TX0,
    PHASE_TX1,
    PHASE_READ
  );

  signal state : state_t := IDLE;
  signal phase : phase_t := PHASE_ADDR;

  signal scl_reg : std_logic := '1';

  -- SDA open-drain:
  -- '1' = forzar SDA a 0
  -- '0' = soltar SDA, queda en Z
  signal sda_drive_low : std_logic := '0';

  signal busy_reg      : std_logic := '0';
  signal done_reg      : std_logic := '0';
  signal ack_error_reg : std_logic := '0';

  signal rw_reg       : std_logic            := '0';
  signal tx_count_reg : unsigned(1 downto 0) := (others => '0');

  signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_reg    : std_logic_vector(7 downto 0) := (others => '0');

  signal bit_index : integer range 0 to 7 := 7;

begin

  SCL <= scl_reg;

  SDA <= '0' when sda_drive_low = '1' else
    'Z';

  busy      <= busy_reg;
  done      <= done_reg;
  ack_error <= ack_error_reg;
  rx_data   <= rx_reg;

  process (clk_i2c)
  begin
    if rising_edge(clk_i2c) then

      if rst = '1' then

        state <= IDLE;
        phase <= PHASE_ADDR;

        scl_reg       <= '1';
        sda_drive_low <= '0';

        busy_reg      <= '0';
        done_reg      <= '0';
        ack_error_reg <= '0';

        rw_reg       <= '0';
        tx_count_reg <= (others => '0');

        shift_reg <= (others => '0');
        rx_reg    <= (others => '0');

        bit_index <= 7;

      else

        -- done solo dura un ciclo
        done_reg <= '0';

        case state is

            --------------------------------------------------
            -- Estado de reposo
            --------------------------------------------------
          when IDLE =>

            scl_reg       <= '1';
            sda_drive_low <= '0';
            busy_reg      <= '0';

            if start = '1' then

              busy_reg      <= '1';
              ack_error_reg <= '0';

              rw_reg       <= rw;
              tx_count_reg <= tx_count;

              -- Primero se envía dirección de esclavo + bit R/W
              shift_reg <= slave_addr & rw;
              bit_index <= 7;
              phase     <= PHASE_ADDR;

              state <= START_SDA_LOW;
            else
              state <= IDLE;
            end if;

            --------------------------------------------------
            -- START: SDA baja mientras SCL está alta
            --------------------------------------------------
          when START_SDA_LOW =>

            scl_reg       <= '1';
            sda_drive_low <= '1';
            state         <= START_SCL_LOW;

          when START_SCL_LOW =>

            scl_reg       <= '0';
            sda_drive_low <= '1';
            state         <= PREPARE_DATA_LOW;

            --------------------------------------------------
            -- Preparación y envío de bits
            --------------------------------------------------
          when PREPARE_DATA_LOW =>

            scl_reg <= '0';

            if shift_reg(bit_index) = '0' then
              sda_drive_low <= '1'; -- preparar 0 en SDA
            else
              sda_drive_low <= '0'; -- soltar SDA para representar 1
            end if;

            state <= SEND_BIT_HIGH;

          when SEND_BIT_HIGH =>

            scl_reg <= '1';

            if bit_index = 0 then
              state <= ACK_LOW;
            else
              bit_index <= bit_index - 1;
              state     <= PREPARE_DATA_LOW;
            end if;

            --------------------------------------------------
            -- Lectura del ACK del esclavo
            --------------------------------------------------
          when ACK_LOW =>

            scl_reg       <= '0';
            sda_drive_low <= '0'; -- soltar SDA para que responda el esclavo
            state         <= ACK_HIGH;

          when ACK_HIGH =>

            scl_reg <= '1';

            if SDA = '1' then
              -- NACK
              ack_error_reg <= '1';
              state         <= STOP_SCL_LOW;

            else
              -- ACK correcto
              case phase is

                when PHASE_ADDR =>

                  if rw_reg = '1' then
                    -- Lectura de un byte
                    phase     <= PHASE_READ;
                    bit_index <= 7;
                    state     <= READ_BIT_LOW;

                  else
                    -- Escritura
                    if tx_count_reg = to_unsigned(1, 2) or
                      tx_count_reg = to_unsigned(2, 2) then

                      shift_reg <= tx_byte0;
                      bit_index <= 7;
                      phase     <= PHASE_TX0;
                      state     <= PREPARE_DATA_LOW;

                    else
                      -- No hay bytes válidos para escribir
                      ack_error_reg <= '1';
                      state         <= STOP_SCL_LOW;
                    end if;
                  end if;

                when PHASE_TX0 =>

                  if tx_count_reg = to_unsigned(2, 2) then
                    shift_reg <= tx_byte1;
                    bit_index <= 7;
                    phase     <= PHASE_TX1;
                    state     <= PREPARE_DATA_LOW;
                  else
                    state <= STOP_SCL_LOW;
                  end if;

                when PHASE_TX1 =>

                  state <= STOP_SCL_LOW;

                when others =>

                  state <= STOP_SCL_LOW;

              end case;
            end if;

            --------------------------------------------------
            -- Lectura de un byte desde el esclavo
            --------------------------------------------------
          when READ_BIT_LOW =>

            scl_reg       <= '0';
            sda_drive_low <= '0'; -- soltar SDA
            state         <= READ_BIT_HIGH;

          when READ_BIT_HIGH =>

            scl_reg           <= '1';
            rx_reg(bit_index) <= SDA;

            if bit_index = 0 then
              state <= READ_NACK_LOW;
            else
              bit_index <= bit_index - 1;
              state     <= READ_BIT_LOW;
            end if;

            --------------------------------------------------
            -- NACK final del maestro en lectura de 1 byte
            --------------------------------------------------
          when READ_NACK_LOW =>

            scl_reg       <= '0';
            sda_drive_low <= '0'; -- soltar SDA = NACK
            state         <= READ_NACK_HIGH;

          when READ_NACK_HIGH =>

            scl_reg       <= '1';
            sda_drive_low <= '0';
            state         <= STOP_SCL_LOW;

            --------------------------------------------------
            -- STOP: SDA sube mientras SCL está alta
            --------------------------------------------------
          when STOP_SCL_LOW =>

            scl_reg <= '0';
            state   <= STOP_SDA_LOW;

          when STOP_SDA_LOW =>

            scl_reg       <= '0';
            sda_drive_low <= '1'; -- SDA baja antes del STOP
            state         <= STOP_SCL_HIGH;

          when STOP_SCL_HIGH =>

            scl_reg       <= '1';
            sda_drive_low <= '1'; -- mantener SDA baja con SCL alta
            state         <= STOP_RELEASE;

          when STOP_RELEASE =>

            scl_reg       <= '1';
            sda_drive_low <= '0'; -- liberar SDA: STOP

            busy_reg <= '0';
            done_reg <= '1';

            state <= WAIT_START_RELEASE;

            --------------------------------------------------
            -- Evita reinicio automático si start queda en 1
            --------------------------------------------------
          when WAIT_START_RELEASE =>

            scl_reg       <= '1';
            sda_drive_low <= '0';
            busy_reg      <= '0';

            if start = '0' then
              state <= IDLE;
            else
              state <= WAIT_START_RELEASE;
            end if;

          when others =>

            state <= IDLE;

        end case;

      end if;

    end if;
  end process;

end architecture;