library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ov7670_runtime_config is
    port (
        clk : in std_logic;
        rst : in std_logic;

        enable     : in std_logic;
        config_btn : in std_logic;
        param_sel  : in std_logic_vector(1 downto 0);
        param_value : in std_logic_vector(7 downto 0);

        i2c_busy      : in std_logic;
        i2c_done      : in std_logic;
        i2c_ack_error : in std_logic;

        i2c_start    : out std_logic;
        i2c_rw       : out std_logic;
        i2c_tx_byte0 : out std_logic_vector(7 downto 0);
        i2c_tx_byte1 : out std_logic_vector(7 downto 0);
        i2c_tx_count : out unsigned(1 downto 0);

        busy  : out std_logic;
        done  : out std_logic;
        error : out std_logic;
        active_param : out std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of ov7670_runtime_config is

    type state_t is (
        IDLE,
        START_WRITE,
        RELEASE_START,
        WAIT_DONE,
        NEXT_WRITE,
        DONE_PULSE,
        ERROR_PULSE
    );

    type reg_pair_t is record
        reg_addr : std_logic_vector(7 downto 0);
        reg_data : std_logic_vector(7 downto 0);
    end record;

    signal state : state_t := IDLE;

    signal btn_meta : std_logic := '0';
    signal btn_sync : std_logic := '0';
    signal btn_prev : std_logic := '0';

    signal latched_sel   : std_logic_vector(1 downto 0) := (others => '0');
    signal latched_value : std_logic_vector(7 downto 0) := (others => '0');
    signal write_index   : integer range 0 to 1 := 0;
    signal write_count   : integer range 1 to 2 := 1;

    signal current_write : reg_pair_t := (
        reg_addr => (others => '0'),
        reg_data => (others => '0')
    );

    signal i2c_start_reg    : std_logic := '0';
    signal i2c_rw_reg       : std_logic := '0';
    signal i2c_tx_byte0_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_byte1_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_tx_count_reg : unsigned(1 downto 0) := (others => '0');

    signal busy_reg  : std_logic := '0';
    signal done_reg  : std_logic := '0';
    signal error_reg : std_logic := '0';

    function write_count_for_param(sel : std_logic_vector(1 downto 0)) return integer is
    begin
        if sel = "01" or sel = "10" then
            return 2;
        end if;

        return 1;
    end function;

    function reg_for_write(
        sel : std_logic_vector(1 downto 0);
        value : std_logic_vector(7 downto 0);
        index : integer
    ) return reg_pair_t is
        variable result : reg_pair_t;
    begin
        result.reg_addr := (others => '0');
        result.reg_data := (others => '0');

        case sel is
            when "00" =>
                result.reg_addr := x"56";
                result.reg_data := value;

            when "01" =>
                if index = 0 then
                    result.reg_addr := x"13";
                    result.reg_data := x"8B";
                else
                    result.reg_addr := x"00";
                    result.reg_data := value;
                end if;

            when "10" =>
                if index = 0 then
                    result.reg_addr := x"13";
                    result.reg_data := x"8E";
                else
                    result.reg_addr := x"10";
                    result.reg_data := value;
                end if;

            when others =>
                result.reg_addr := x"55";
                result.reg_data := value;
        end case;

        return result;
    end function;

begin

    i2c_start    <= i2c_start_reg;
    i2c_rw       <= i2c_rw_reg;
    i2c_tx_byte0 <= i2c_tx_byte0_reg;
    i2c_tx_byte1 <= i2c_tx_byte1_reg;
    i2c_tx_count <= i2c_tx_count_reg;

    busy <= busy_reg;
    done <= done_reg;
    error <= error_reg;
    active_param <= latched_sel;

    process(clk)
        variable next_reg_pair : reg_pair_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;

                btn_meta <= '0';
                btn_sync <= '0';
                btn_prev <= '0';

                latched_sel   <= (others => '0');
                latched_value <= (others => '0');
                write_index   <= 0;
                write_count   <= 1;
                current_write <= (
                    reg_addr => (others => '0'),
                    reg_data => (others => '0')
                );

                i2c_start_reg    <= '0';
                i2c_rw_reg       <= '0';
                i2c_tx_byte0_reg <= (others => '0');
                i2c_tx_byte1_reg <= (others => '0');
                i2c_tx_count_reg <= (others => '0');

                busy_reg  <= '0';
                done_reg  <= '0';
                error_reg <= '0';
            else
                btn_meta <= config_btn;
                btn_sync <= btn_meta;
                btn_prev <= btn_sync;

                i2c_start_reg <= '0';
                done_reg <= '0';
                error_reg <= '0';

                case state is
                    when IDLE =>
                        busy_reg <= '0';

                        if enable = '1' and btn_sync = '1' and btn_prev = '0' and i2c_busy = '0' then
                            latched_sel   <= param_sel;
                            latched_value <= param_value;
                            write_index   <= 0;
                            write_count   <= write_count_for_param(param_sel);
                            current_write <= reg_for_write(param_sel, param_value, 0);
                            busy_reg      <= '1';
                            state         <= START_WRITE;
                        end if;

                    when START_WRITE =>
                        i2c_rw_reg       <= '0';
                        i2c_tx_byte0_reg <= current_write.reg_addr;
                        i2c_tx_byte1_reg <= current_write.reg_data;
                        i2c_tx_count_reg <= to_unsigned(2, 2);
                        i2c_start_reg    <= '1';
                        busy_reg         <= '1';
                        state            <= RELEASE_START;

                    when RELEASE_START =>
                        busy_reg <= '1';
                        state <= WAIT_DONE;

                    when WAIT_DONE =>
                        busy_reg <= '1';

                        if i2c_done = '1' then
                            if i2c_ack_error = '1' then
                                state <= ERROR_PULSE;
                            else
                                state <= NEXT_WRITE;
                            end if;
                        end if;

                    when NEXT_WRITE =>
                        busy_reg <= '1';

                        if write_index = write_count - 1 then
                            state <= DONE_PULSE;
                        elsif i2c_busy = '0' then
                            write_index <= write_index + 1;
                            next_reg_pair := reg_for_write(latched_sel, latched_value, write_index + 1);
                            current_write <= next_reg_pair;
                            state <= START_WRITE;
                        end if;

                    when DONE_PULSE =>
                        busy_reg <= '0';
                        done_reg <= '1';
                        state <= IDLE;

                    when ERROR_PULSE =>
                        busy_reg <= '0';
                        error_reg <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture;
