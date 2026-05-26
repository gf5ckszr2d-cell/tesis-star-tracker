library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_star_tracker_top is
end entity;

architecture sim of tb_star_tracker_top is

    component star_tracker_top is
        port (
            clk : in std_logic;
            rst : in std_logic;

            start_btn : in std_logic;
            sw        : in std_logic_vector(15 downto 0);

            SDA : inout std_logic;
            SCL : out std_logic;

            led_read_data : out std_logic_vector(7 downto 0);
            busy          : out std_logic;
            ok            : out std_logic;
            fail          : out std_logic
        );
    end component;

    constant CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal start_btn : std_logic := '0';
    signal sw        : std_logic_vector(15 downto 0) := (others => '0');

    signal SDA : std_logic := 'H';
    signal SCL : std_logic;

    signal led_read_data : std_logic_vector(7 downto 0);
    signal busy          : std_logic;
    signal ok            : std_logic;
    signal fail          : std_logic;

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

    uut : star_tracker_top
        port map (
            clk => clk,
            rst => rst,

            start_btn => start_btn,
            sw        => sw,

            SDA => SDA,
            SCL => SCL,

            led_read_data => led_read_data,
            busy          => busy,
            ok            => ok,
            fail          => fail
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
        report "Inicio de simulacion star_tracker_top";

        rst <= '1';
        start_btn <= '0';
        sw <= x"1502";

        wait for 20 * CLK_PERIOD;

        rst <= '0';
        wait until rising_edge(clk);

        start_btn <= '1';

        wait until ok = '1' or fail = '1' for 5 ms;

        assert ok = '1'
            report "ERROR: ok no se activo"
            severity failure;

        assert fail = '0'
            report "ERROR: fail se activo"
            severity failure;

        assert led_read_data = x"02"
            report "ERROR: led_read_data no coincide con 0x02"
            severity failure;

        start_btn <= '0';

        wait for 20 * CLK_PERIOD;

        assert busy = '0'
            report "ERROR: busy no regreso a 0"
            severity failure;

        report "Simulacion star_tracker_top finalizada correctamente";

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

        procedure send_slave_byte(
            constant data_value : in std_logic_vector(7 downto 0)
        ) is
        begin
            for bit_index in 7 downto 0 loop

                if data_value(bit_index) = '0' then
                    sda_slave_drive <= '0';
                else
                    sda_slave_drive <= 'Z';
                end if;

                wait until rising_edge(SCL);
                wait until falling_edge(SCL);

            end loop;

            sda_slave_drive <= 'Z';

            wait until rising_edge(SCL);
            wait until falling_edge(SCL);
        end procedure;

        variable received_byte : std_logic_vector(7 downto 0);

    begin

        sda_slave_drive <= 'Z';

        wait until rst = '0';

        wait_start;

        receive_master_byte(received_byte);
        assert received_byte = x"42"
            report "ERROR: primer byte de escritura no es 0x42"
            severity failure;
        send_ack;

        receive_master_byte(received_byte);
        assert received_byte = x"15"
            report "ERROR: registro de escritura no es 0x15"
            severity failure;
        send_ack;

        receive_master_byte(received_byte);
        assert received_byte = x"02"
            report "ERROR: dato de escritura no es 0x02"
            severity failure;
        send_ack;

        wait_start;

        receive_master_byte(received_byte);
        assert received_byte = x"42"
            report "ERROR: byte de point no es 0x42"
            severity failure;
        send_ack;

        receive_master_byte(received_byte);
        assert received_byte = x"15"
            report "ERROR: registro de point no es 0x15"
            severity failure;
        send_ack;

        wait_start;

        receive_master_byte(received_byte);
        assert received_byte = x"43"
            report "ERROR: byte de lectura no es 0x43"
            severity failure;
        send_ack;

        send_slave_byte(x"02");

        wait;

    end process;

end architecture;