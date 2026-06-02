library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ov7670_init_config is
    generic (
        CLK_FREQ_HZ    : integer := 100000000;
        RESET_DELAY_MS : integer := 1
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        start : in std_logic;

        i2c_done      : in std_logic;
        i2c_ack_error : in std_logic;

        i2c_start    : out std_logic;
        i2c_rw       : out std_logic;
        i2c_tx_byte0 : out std_logic_vector(7 downto 0);
        i2c_tx_byte1 : out std_logic_vector(7 downto 0);
        i2c_tx_count : out unsigned(1 downto 0);

        busy         : out std_logic;
        done         : out std_logic;
        error        : out std_logic;
        current_step : out unsigned(4 downto 0)
    );
end entity;

architecture rtl of ov7670_init_config is

    type state_t is (
        IDLE,
        LOAD_PAIR,
        START_WRITE,
        WAIT_WRITE_DONE,
        WAIT_RESET_DELAY,
        NEXT_PAIR,
        DONE_STATE,
        ERROR_STATE,
        WAIT_START_RELEASE
    );

    type reg_pair_t is record
        reg_addr : std_logic_vector(7 downto 0);
        reg_data : std_logic_vector(7 downto 0);
    end record;

    type config_rom_t is array (natural range <>) of reg_pair_t;

    constant CONFIG_ROM : config_rom_t := (
        -- Reset
        (reg_addr => x"12", reg_data => x"80"),

        -- Basic output and sync control
        (reg_addr => x"15", reg_data => x"00"),
        (reg_addr => x"40", reg_data => x"C0"),
        (reg_addr => x"13", reg_data => x"8F"),

        -- QQVGA YUV format and scaling
        (reg_addr => x"11", reg_data => x"01"),
        (reg_addr => x"12", reg_data => x"00"),
        (reg_addr => x"0C", reg_data => x"04"),
        (reg_addr => x"3E", reg_data => x"1A"),
        (reg_addr => x"70", reg_data => x"3A"),
        (reg_addr => x"71", reg_data => x"35"),
        (reg_addr => x"72", reg_data => x"22"),
        (reg_addr => x"73", reg_data => x"F2"),
        (reg_addr => x"A2", reg_data => x"02"),

        -- Byte order
        (reg_addr => x"3A", reg_data => x"04"),
        (reg_addr => x"3D", reg_data => x"99"),

        -- Active VGA window, later scaled to QQVGA
        (reg_addr => x"03", reg_data => x"03"),
        (reg_addr => x"17", reg_data => x"11"),
        (reg_addr => x"18", reg_data => x"61"),
        (reg_addr => x"19", reg_data => x"03"),
        (reg_addr => x"1A", reg_data => x"7B"),
        (reg_addr => x"32", reg_data => x"80")
    );

    constant CONFIG_LEN         : integer := CONFIG_ROM'length;
    constant RESET_DELAY_CYCLES : integer := (CLK_FREQ_HZ / 1000) * RESET_DELAY_MS;

    signal state : state_t := IDLE;

    signal config_index : integer range 0 to CONFIG_LEN - 1 := 0;
    signal delay_count  : integer range 0 to RESET_DELAY_CYCLES := 0;

    signal i2c_start_reg    : std_logic := '0';
    signal i2c_rw_reg       : std_logic := '0';
    signal i2c_tx_byte0_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_byte1_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_count_reg : unsigned(1 downto 0) := (others => '0');

    signal done_reg  : std_logic := '0';
    signal error_reg : std_logic := '0';

begin

    i2c_start    <= i2c_start_reg;
    i2c_rw       <= i2c_rw_reg;
    i2c_tx_byte0 <= i2c_tx_byte0_reg;
    i2c_tx_byte1 <= i2c_tx_byte1_reg;
    i2c_tx_count <= i2c_tx_count_reg;

    done  <= done_reg;
    error <= error_reg;

    busy <= '1' when state /= IDLE and
                     state /= DONE_STATE and
                     state /= ERROR_STATE and
                     state /= WAIT_START_RELEASE else '0';

    current_step <= to_unsigned(config_index, current_step'length);

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then

                state <= IDLE;

                config_index <= 0;
                delay_count  <= 0;

                i2c_start_reg    <= '0';
                i2c_rw_reg       <= '0';
                i2c_tx_byte0_reg <= (others => '0');
                i2c_tx_byte1_reg <= (others => '0');
                i2c_tx_count_reg <= (others => '0');

                done_reg  <= '0';
                error_reg <= '0';

            else

                i2c_start_reg <= '0';

                case state is

                    when IDLE =>

                        done_reg  <= '0';
                        error_reg <= '0';

                        if start = '1' then
                            config_index <= 0;
                            delay_count  <= 0;
                            state        <= LOAD_PAIR;
                        else
                            state <= IDLE;
                        end if;

                    when LOAD_PAIR =>

                        i2c_rw_reg       <= '0';
                        i2c_tx_byte0_reg <= CONFIG_ROM(config_index).reg_addr;
                        i2c_tx_byte1_reg <= CONFIG_ROM(config_index).reg_data;
                        i2c_tx_count_reg <= to_unsigned(2, 2);

                        state <= START_WRITE;

                    when START_WRITE =>

                        i2c_start_reg <= '1';
                        state         <= WAIT_WRITE_DONE;

                    when WAIT_WRITE_DONE =>

                        if i2c_done = '1' then
                            if i2c_ack_error = '1' then
                                error_reg <= '1';
                                state     <= ERROR_STATE;
                            elsif config_index = 0 then
                                delay_count <= 0;
                                state       <= WAIT_RESET_DELAY;
                            else
                                state <= NEXT_PAIR;
                            end if;
                        else
                            state <= WAIT_WRITE_DONE;
                        end if;

                    when WAIT_RESET_DELAY =>

                        if delay_count = RESET_DELAY_CYCLES then
                            state <= NEXT_PAIR;
                        else
                            delay_count <= delay_count + 1;
                            state       <= WAIT_RESET_DELAY;
                        end if;

                    when NEXT_PAIR =>

                        if config_index = CONFIG_LEN - 1 then
                            done_reg <= '1';
                            state    <= DONE_STATE;
                        else
                            config_index <= config_index + 1;
                            state        <= LOAD_PAIR;
                        end if;

                    when DONE_STATE =>

                        done_reg <= '1';
                        state    <= WAIT_START_RELEASE;

                    when ERROR_STATE =>

                        error_reg <= '1';
                        state     <= WAIT_START_RELEASE;

                    when WAIT_START_RELEASE =>

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
