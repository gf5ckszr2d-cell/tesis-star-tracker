library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ov7670_init_config is
end entity;

architecture sim of tb_ov7670_init_config is

    component ov7670_init_config is
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
    end component;

    component i2c_master is
        generic (
            CLK_FREQ_HZ : integer := 100000000;
            I2C_SCL_HZ  : integer := 100000
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

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

    type reg_pair_t is record
        reg_addr : std_logic_vector(7 downto 0);
        reg_data : std_logic_vector(7 downto 0);
    end record;

    type config_rom_t is array (natural range <>) of reg_pair_t;

    constant EXPECTED_CONFIG : config_rom_t := (
        (reg_addr => x"12", reg_data => x"80"),
        (reg_addr => x"15", reg_data => x"00"),
        (reg_addr => x"40", reg_data => x"C0"),
        (reg_addr => x"13", reg_data => x"8F"),
        (reg_addr => x"11", reg_data => x"01"),
        (reg_addr => x"12", reg_data => x"00"),
        (reg_addr => x"0C", reg_data => x"04"),
        (reg_addr => x"3E", reg_data => x"1A"),
        (reg_addr => x"70", reg_data => x"3A"),
        (reg_addr => x"71", reg_data => x"35"),
        (reg_addr => x"72", reg_data => x"22"),
        (reg_addr => x"73", reg_data => x"F2"),
        (reg_addr => x"A2", reg_data => x"02"),
        (reg_addr => x"3A", reg_data => x"04"),
        (reg_addr => x"3D", reg_data => x"99"),
        (reg_addr => x"03", reg_data => x"03"),
        (reg_addr => x"17", reg_data => x"11"),
        (reg_addr => x"18", reg_data => x"61"),
        (reg_addr => x"19", reg_data => x"03"),
        (reg_addr => x"1A", reg_data => x"7B"),
        (reg_addr => x"32", reg_data => x"80")
    );

    constant CLK_PERIOD : time := 1 us;
    constant OV7670_ADDR : std_logic_vector(6 downto 0) := "0100001";

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal start : std_logic := '0';

    signal ctrl_i2c_start    : std_logic;
    signal ctrl_i2c_rw       : std_logic;
    signal ctrl_i2c_tx_byte0 : std_logic_vector(7 downto 0);
    signal ctrl_i2c_tx_byte1 : std_logic_vector(7 downto 0);
    signal ctrl_i2c_tx_count : unsigned(1 downto 0);

    signal i2c_rx_data   : std_logic_vector(7 downto 0);
    signal i2c_done      : std_logic;
    signal i2c_ack_error : std_logic;
    signal i2c_busy      : std_logic;

    signal init_busy    : std_logic;
    signal init_done    : std_logic;
    signal init_error   : std_logic;
    signal current_step : unsigned(4 downto 0);

    signal SDA : std_logic := 'H';
    signal SCL : std_logic;

    signal sda_slave_drive : std_logic := 'Z';

    function sda_to_bit(signal_value : std_logic) return std_logic is
    begin
        if signal_value = '0' then
            return '0';
        else
            return '1';
        end if;
    end function;

begin

    SDA <= 'H';
    SDA <= sda_slave_drive;

    u_init_config : ov7670_init_config
        generic map (
            CLK_FREQ_HZ    => 1000000,
            RESET_DELAY_MS => 1
        )
        port map (
            clk => clk,
            rst => rst,

            start => start,

            i2c_done      => i2c_done,
            i2c_ack_error => i2c_ack_error,

            i2c_start    => ctrl_i2c_start,
            i2c_rw       => ctrl_i2c_rw,
            i2c_tx_byte0 => ctrl_i2c_tx_byte0,
            i2c_tx_byte1 => ctrl_i2c_tx_byte1,
            i2c_tx_count => ctrl_i2c_tx_count,

            busy         => init_busy,
            done         => init_done,
            error        => init_error,
            current_step => current_step
        );

    u_i2c_master : i2c_master
        generic map (
            CLK_FREQ_HZ => 1000000,
            I2C_SCL_HZ  => 100000
        )
        port map (
            clk => clk,
            rst => rst,

            start      => ctrl_i2c_start,
            slave_addr => OV7670_ADDR,
            rw         => ctrl_i2c_rw,

            tx_byte0 => ctrl_i2c_tx_byte0,
            tx_byte1 => ctrl_i2c_tx_byte1,
            tx_count => ctrl_i2c_tx_count,

            rx_data => i2c_rx_data,

            SDA => SDA,
            SCL => SCL,

            busy      => i2c_busy,
            done      => i2c_done,
            ack_error => i2c_ack_error
        );

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    stimulus : process
    begin
        report "Inicio de simulacion integrada ov7670_init_config + i2c_master";

        rst <= '1';
        start <= '0';

        wait for 5 * CLK_PERIOD;

        rst <= '0';
        wait until rising_edge(clk);

        start <= '1';

        wait until init_done = '1' or init_error = '1' for 20 ms;

        assert init_done = '1'
            report "ERROR: timeout esperando fin de configuracion"
            severity failure;

        assert init_error = '0'
            report "ERROR: init_error activo"
            severity failure;

        assert i2c_ack_error = '0'
            report "ERROR: i2c_ack_error activo"
            severity failure;

        start <= '0';
        wait for 5 * CLK_PERIOD;

        assert init_busy = '0'
            report "ERROR: init_busy debe quedar en 0"
            severity failure;

        report "Simulacion integrada ov7670_init_config + i2c_master finalizada correctamente";

        wait;
    end process;

    slave_model : process

        procedure wait_start is
        begin
            wait until SDA = '0' and SCL = '1';
        end procedure;

        procedure receive_master_byte(
            variable received_byte : out std_logic_vector(7 downto 0)
        ) is
        begin
            received_byte := (others => '0');

            for bit_index in 7 downto 0 loop
                wait until rising_edge(SCL);
                received_byte(bit_index) := sda_to_bit(SDA);
            end loop;
        end procedure;

        procedure send_ack is
        begin
            wait until falling_edge(SCL);
            sda_slave_drive <= '0';

            wait until rising_edge(SCL);
            wait until falling_edge(SCL);

            sda_slave_drive <= 'Z';
        end procedure;

        variable received_byte : std_logic_vector(7 downto 0);

    begin

        sda_slave_drive <= 'Z';

        wait until rst = '0';

        for index in EXPECTED_CONFIG'range loop

            wait_start;

            receive_master_byte(received_byte);
            assert received_byte = x"42"
                report "ERROR: byte de direccion de escritura no es 0x42"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_addr
                report "ERROR: direccion de registro no coincide"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_data
                report "ERROR: dato de registro no coincide"
                severity failure;
            send_ack;

            assert current_step = to_unsigned(index, current_step'length)
                report "ERROR: current_step no coincide con el par enviado"
                severity failure;

        end loop;

        wait;
    end process;

end architecture;
