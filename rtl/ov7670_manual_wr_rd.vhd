library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ov7670_manual_wr_rd is
    port (
        clk_i2c : in std_logic;  -- mismo reloj que usa el i2c_master
        rst     : in std_logic;

        start_btn : in std_logic;
        sw        : in std_logic_vector(15 downto 0);

        SDA : inout std_logic;
        SCL : out std_logic;

        led_read_data : out std_logic_vector(7 downto 0);

        busy : out std_logic;
        ok   : out std_logic;
        fail : out std_logic
    );
end entity;

architecture rtl of ov7670_manual_wr_rd is

    component i2c_master is
        port (
            clk_i2c : in std_logic;
            rst     : in std_logic;

            start      : in std_logic;
            slave_addr : in std_logic_vector(6 downto 0);
            rw         : in std_logic;

            tx_byte0 : in std_logic_vector(7 downto 0);
            tx_byte1 : in std_logic_vector(7 downto 0);
            tx_count : in unsigned(1 downto 0);

            rx_data : out std_logic_vector(7 downto 0);

            SDA : inout std_logic;
            SCL : out std_logic;

            busy      : out std_logic;
            done      : out std_logic;
            ack_error : out std_logic
        );
    end component;

    constant OV7670_ADDR : std_logic_vector(6 downto 0) := "0100001";
    -- "0100001" & '0' = x"42" escritura
    -- "0100001" & '1' = x"43" lectura

    type state_t is (
        IDLE,
        CAPTURE_SWITCHES,

        START_WRITE,
        WAIT_WRITE_DONE,

        START_POINT_REGISTER,
        WAIT_POINT_DONE,

        START_READ,
        WAIT_READ_DONE,

        VERIFY_DATA,
        WAIT_RELEASE
    );

    signal state : state_t := IDLE;

    signal reg_addr_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal write_data_latched : std_logic_vector(7 downto 0) := (others => '0');
    signal read_data_latched  : std_logic_vector(7 downto 0) := (others => '0');

    signal i2c_start     : std_logic := '0';
    signal i2c_rw        : std_logic := '0';
    signal i2c_tx_byte0  : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_byte1  : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_count  : unsigned(1 downto 0) := (others => '0');

    signal i2c_rx_data   : std_logic_vector(7 downto 0);
    signal i2c_busy      : std_logic;
    signal i2c_done      : std_logic;
    signal i2c_ack_error : std_logic;

    signal ok_reg   : std_logic := '0';
    signal fail_reg : std_logic := '0';

begin

    led_read_data <= read_data_latched;

    ok   <= ok_reg;
    fail <= fail_reg;

    busy <= '1' when state /= IDLE and state /= WAIT_RELEASE else '0';

    --------------------------------------------------------------------
    -- Instancia del maestro I2C
    --------------------------------------------------------------------
    u_i2c_master : i2c_master
        port map (
            clk_i2c => clk_i2c,
            rst     => rst,

            start      => i2c_start,
            slave_addr => OV7670_ADDR,
            rw         => i2c_rw,

            tx_byte0 => i2c_tx_byte0,
            tx_byte1 => i2c_tx_byte1,
            tx_count => i2c_tx_count,

            rx_data => i2c_rx_data,

            SDA => SDA,
            SCL => SCL,

            busy      => i2c_busy,
            done      => i2c_done,
            ack_error => i2c_ack_error
        );

    --------------------------------------------------------------------
    -- FSM: escritura manual + lectura + verificación
    --------------------------------------------------------------------
    process(clk_i2c)
    begin
        if rising_edge(clk_i2c) then

            if rst = '1' then

                state <= IDLE;

                reg_addr_latched   <= (others => '0');
                write_data_latched <= (others => '0');
                read_data_latched  <= (others => '0');

                i2c_start    <= '0';
                i2c_rw       <= '0';
                i2c_tx_byte0 <= (others => '0');
                i2c_tx_byte1 <= (others => '0');
                i2c_tx_count <= (others => '0');

                ok_reg   <= '0';
                fail_reg <= '0';

            else

                -- Por defecto, el start del I2C dura solo un ciclo
                i2c_start <= '0';

                case state is

                    ----------------------------------------------------
                    -- Espera orden manual
                    ----------------------------------------------------
                    when IDLE =>

                        if start_btn = '1' then
                            ok_reg   <= '0';
                            fail_reg <= '0';
                            state    <= CAPTURE_SWITCHES;
                        else
                            state <= IDLE;
                        end if;

                    ----------------------------------------------------
                    -- Captura switches
                    -- sw[15:8] = registro
                    -- sw[7:0]  = dato
                    ----------------------------------------------------
                    when CAPTURE_SWITCHES =>

                        reg_addr_latched   <= sw(15 downto 8);
                        write_data_latched <= sw(7 downto 0);

                        state <= START_WRITE;

                    ----------------------------------------------------
                    -- Escritura:
                    -- START -> x42 -> reg_addr -> write_data -> STOP
                    ----------------------------------------------------
                    when START_WRITE =>

                        i2c_rw       <= '0';
                        i2c_tx_byte0 <= reg_addr_latched;
                        i2c_tx_byte1 <= write_data_latched;
                        i2c_tx_count <= to_unsigned(2, 2);

                        i2c_start <= '1';

                        state <= WAIT_WRITE_DONE;

                    when WAIT_WRITE_DONE =>

                        if i2c_done = '1' then

                            if i2c_ack_error = '1' then
                                fail_reg <= '1';
                                ok_reg   <= '0';
                                state    <= WAIT_RELEASE;
                            else
                                state <= START_POINT_REGISTER;
                            end if;

                        else
                            state <= WAIT_WRITE_DONE;
                        end if;

                    ----------------------------------------------------
                    -- Apuntar al registro antes de leer:
                    -- START -> x42 -> reg_addr -> STOP
                    ----------------------------------------------------
                    when START_POINT_REGISTER =>

                        i2c_rw       <= '0';
                        i2c_tx_byte0 <= reg_addr_latched;
                        i2c_tx_byte1 <= (others => '0');
                        i2c_tx_count <= to_unsigned(1, 2);

                        i2c_start <= '1';

                        state <= WAIT_POINT_DONE;

                    when WAIT_POINT_DONE =>

                        if i2c_done = '1' then

                            if i2c_ack_error = '1' then
                                fail_reg <= '1';
                                ok_reg   <= '0';
                                state    <= WAIT_RELEASE;
                            else
                                state <= START_READ;
                            end if;

                        else
                            state <= WAIT_POINT_DONE;
                        end if;

                    ----------------------------------------------------
                    -- Lectura:
                    -- START -> x43 -> read_data -> NACK -> STOP
                    ----------------------------------------------------
                    when START_READ =>

                        i2c_rw       <= '1';
                        i2c_tx_byte0 <= (others => '0');
                        i2c_tx_byte1 <= (others => '0');
                        i2c_tx_count <= (others => '0');

                        i2c_start <= '1';

                        state <= WAIT_READ_DONE;

                    when WAIT_READ_DONE =>

                        if i2c_done = '1' then

                            if i2c_ack_error = '1' then
                                fail_reg <= '1';
                                ok_reg   <= '0';
                                state    <= WAIT_RELEASE;
                            else
                                read_data_latched <= i2c_rx_data;
                                state <= VERIFY_DATA;
                            end if;

                        else
                            state <= WAIT_READ_DONE;
                        end if;

                    ----------------------------------------------------
                    -- Compara lectura contra escritura
                    ----------------------------------------------------
                    when VERIFY_DATA =>

                        if read_data_latched = write_data_latched then
                            ok_reg   <= '1';
                            fail_reg <= '0';
                        else
                            ok_reg   <= '0';
                            fail_reg <= '1';
                        end if;

                        state <= WAIT_RELEASE;

                    ----------------------------------------------------
                    -- Espera soltar botón para no repetir
                    ----------------------------------------------------
                    when WAIT_RELEASE =>

                        if start_btn = '0' then
                            state <= IDLE;
                        else
                            state <= WAIT_RELEASE;
                        end if;

                    when others =>

                        state <= IDLE;

                end case;

            end if;

        end if;
    end process;

end architecture;