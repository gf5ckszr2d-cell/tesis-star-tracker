library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ov7670_manual_ctrl is
    port (
        clk : in std_logic;
        rst : in std_logic;

        start_btn : in std_logic;
        sw        : in std_logic_vector(15 downto 0);

        i2c_done      : in std_logic;
        i2c_ack_error : in std_logic;
        i2c_rx_data   : in std_logic_vector(7 downto 0);

        i2c_start    : out std_logic;
        i2c_rw       : out std_logic;
        i2c_tx_byte0 : out std_logic_vector(7 downto 0);
        i2c_tx_byte1 : out std_logic_vector(7 downto 0);
        i2c_tx_count : out unsigned(1 downto 0);

        led_read_data : out std_logic_vector(7 downto 0);
        busy          : out std_logic;
        ok            : out std_logic;
        fail          : out std_logic
    );
end entity;

architecture rtl of ov7670_manual_ctrl is

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

    signal i2c_start_reg    : std_logic := '0';
    signal i2c_rw_reg       : std_logic := '0';
    signal i2c_tx_byte0_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_byte1_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_count_reg : unsigned(1 downto 0) := (others => '0');

    signal ok_reg   : std_logic := '0';
    signal fail_reg : std_logic := '0';

begin

    i2c_start    <= i2c_start_reg;
    i2c_rw       <= i2c_rw_reg;
    i2c_tx_byte0 <= i2c_tx_byte0_reg;
    i2c_tx_byte1 <= i2c_tx_byte1_reg;
    i2c_tx_count <= i2c_tx_count_reg;

    led_read_data <= read_data_latched;

    ok   <= ok_reg;
    fail <= fail_reg;

    busy <= '1' when state /= IDLE and state /= WAIT_RELEASE else '0';

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then

                state <= IDLE;

                reg_addr_latched   <= (others => '0');
                write_data_latched <= (others => '0');
                read_data_latched  <= (others => '0');

                i2c_start_reg    <= '0';
                i2c_rw_reg       <= '0';
                i2c_tx_byte0_reg <= (others => '0');
                i2c_tx_byte1_reg <= (others => '0');
                i2c_tx_count_reg <= (others => '0');

                ok_reg   <= '0';
                fail_reg <= '0';

            else

                i2c_start_reg <= '0';

                case state is

                    when IDLE =>

                        if start_btn = '1' then
                            ok_reg   <= '0';
                            fail_reg <= '0';
                            state    <= CAPTURE_SWITCHES;
                        else
                            state <= IDLE;
                        end if;

                    when CAPTURE_SWITCHES =>

                        reg_addr_latched   <= sw(15 downto 8);
                        write_data_latched <= sw(7 downto 0);

                        state <= START_WRITE;

                    when START_WRITE =>

                        i2c_rw_reg       <= '0';
                        i2c_tx_byte0_reg <= reg_addr_latched;
                        i2c_tx_byte1_reg <= write_data_latched;
                        i2c_tx_count_reg <= to_unsigned(2, 2);

                        i2c_start_reg <= '1';

                        state <= WAIT_WRITE_DONE;

                    when WAIT_WRITE_DONE =>

                        if i2c_done = '1' then

                            if i2c_ack_error = '1' then
                                ok_reg   <= '0';
                                fail_reg <= '1';
                                state    <= WAIT_RELEASE;
                            else
                                state <= START_POINT_REGISTER;
                            end if;

                        else
                            state <= WAIT_WRITE_DONE;
                        end if;

                    when START_POINT_REGISTER =>

                        i2c_rw_reg       <= '0';
                        i2c_tx_byte0_reg <= reg_addr_latched;
                        i2c_tx_byte1_reg <= (others => '0');
                        i2c_tx_count_reg <= to_unsigned(1, 2);

                        i2c_start_reg <= '1';

                        state <= WAIT_POINT_DONE;

                    when WAIT_POINT_DONE =>

                        if i2c_done = '1' then

                            if i2c_ack_error = '1' then
                                ok_reg   <= '0';
                                fail_reg <= '1';
                                state    <= WAIT_RELEASE;
                            else
                                state <= START_READ;
                            end if;

                        else
                            state <= WAIT_POINT_DONE;
                        end if;

                    when START_READ =>

                        i2c_rw_reg       <= '1';
                        i2c_tx_byte0_reg <= (others => '0');
                        i2c_tx_byte1_reg <= (others => '0');
                        i2c_tx_count_reg <= (others => '0');

                        i2c_start_reg <= '1';

                        state <= WAIT_READ_DONE;

                    when WAIT_READ_DONE =>

                        if i2c_done = '1' then

                            if i2c_ack_error = '1' then
                                ok_reg   <= '0';
                                fail_reg <= '1';
                                state    <= WAIT_RELEASE;
                            else
                                read_data_latched <= i2c_rx_data;
                                state <= VERIFY_DATA;
                            end if;

                        else
                            state <= WAIT_READ_DONE;
                        end if;

                    when VERIFY_DATA =>

                        if read_data_latched = write_data_latched then
                            ok_reg   <= '1';
                            fail_reg <= '0';
                        else
                            ok_reg   <= '0';
                            fail_reg <= '1';
                        end if;

                        state <= WAIT_RELEASE;

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