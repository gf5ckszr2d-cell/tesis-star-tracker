library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_camera_config_integration_top is
end entity;

architecture sim of tb_camera_config_integration_top is
    type reg_pair_t is record
        reg_addr : std_logic_vector(7 downto 0);
        reg_data : std_logic_vector(7 downto 0);
    end record;
    type config_rom_t is array (natural range <>) of reg_pair_t;

    constant EXPECTED_CONFIG : config_rom_t := (
        (x"12", x"80"), (x"15", x"00"), (x"40", x"C0"),
        (x"13", x"8F"), (x"11", x"01"), (x"12", x"00"),
        (x"0C", x"04"), (x"3E", x"1A"), (x"70", x"3A"),
        (x"71", x"35"), (x"72", x"22"), (x"73", x"F2"),
        (x"A2", x"02"), (x"3A", x"04"), (x"3D", x"99"),
        (x"03", x"03"), (x"17", x"11"), (x"18", x"61"),
        (x"19", x"03"), (x"1A", x"7B"), (x"32", x"80")
    );

    constant CLK_PERIOD : time := 10 ns;

    signal clk, rst, init_start : std_logic := '0';
    signal runtime_enable, config_btn : std_logic := '0';
    signal param_sel : std_logic_vector(1 downto 0) := (others => '0');
    signal param_value : std_logic_vector(7 downto 0) := (others => '0');
    signal SDA : std_logic := 'H';
    signal SCL : std_logic;
    signal sda_slave_drive : std_logic := 'Z';

    signal init_busy, init_done, init_error : std_logic;
    signal init_current_step : unsigned(4 downto 0);
    signal runtime_busy, runtime_done, runtime_error : std_logic;
    signal runtime_active_param : std_logic_vector(1 downto 0);
    signal i2c_busy, i2c_done, i2c_ack_error, i2c_runtime_owner : std_logic;
    signal transaction_count : integer range 0 to 28 := 0;

    function bus_bit(value : std_logic) return std_logic is
    begin
        if value = '0' then return '0'; else return '1'; end if;
    end function;
begin
    SDA <= 'H';
    SDA <= sda_slave_drive;

    uut : entity work.camera_config_integration_top
        generic map (
            CLK_FREQ_HZ => 100000000,
            I2C_SCL_HZ => 100000,
            RESET_DELAY_MS => 1
        )
        port map (
            clk => clk, rst => rst, init_start => init_start,
            runtime_enable => runtime_enable, config_btn => config_btn,
            param_sel => param_sel, param_value => param_value,
            SDA => SDA, SCL => SCL, init_busy => init_busy,
            init_done => init_done, init_error => init_error,
            init_current_step => init_current_step,
            runtime_busy => runtime_busy, runtime_done => runtime_done,
            runtime_error => runtime_error,
            runtime_active_param => runtime_active_param,
            i2c_busy => i2c_busy, i2c_done => i2c_done,
            i2c_ack_error => i2c_ack_error,
            i2c_runtime_owner => i2c_runtime_owner
        );

    clk <= not clk after CLK_PERIOD / 2;

    stimulus : process
        procedure wait_clocks(count : positive) is
        begin
            for index in 1 to count loop wait until rising_edge(clk); end loop;
        end procedure;

        procedure pulse_config(
            sel : std_logic_vector(1 downto 0);
            value : std_logic_vector(7 downto 0)
        ) is
        begin
            param_sel <= sel;
            param_value <= value;
            wait_clocks(2);
            config_btn <= '1';
            wait_clocks(4);
            config_btn <= '0';
        end procedure;
    begin
        report "============================================================";
        report "TEST INTEGRADO 1: CONFIGURACION DE CAMARA";
        report "i2c_master + ov7670_init_config + ov7670_runtime_config";
        report "============================================================";

        rst <= '1';
        wait_clocks(10);
        rst <= '0';
        runtime_enable <= '1';

        report "[FASE 1/4] Runtime debe quedar bloqueado antes de init";
        pulse_config("00", x"60");
        wait for 50 us;
        assert transaction_count = 0
            report "ERROR: runtime uso I2C antes de completar init" severity failure;
        report "[OK 1/4] Arbitraje bloqueo runtime antes de init";

        report "[FASE 2/4] Verificando los 21 registros de la ROM";
        init_start <= '1';
        wait until init_done = '1' or init_error = '1' for 15 ms;
        assert init_done = '1' report "ERROR: init no termino" severity failure;
        assert init_error = '0' report "ERROR: init_error activo" severity failure;
        assert i2c_ack_error = '0' report "ERROR: ACK fallo durante init" severity failure;
        assert transaction_count = 21
            report "ERROR: cantidad de escrituras init distinta de 21" severity failure;
        init_start <= '0';
        wait_clocks(10);
        report "[OK 2/4] ROM completa, direccion 0x42 y ACK verificados";

        report "[FASE 3/4] Verificando configuracion durante operacion";
        pulse_config("00", x"60");
        wait until transaction_count = 22 for 2 ms;
        wait until runtime_done = '1' for 1 ms;

        pulse_config("01", x"12");
        wait until transaction_count = 24 for 3 ms;
        wait until runtime_done = '1' for 1 ms;

        pulse_config("10", x"34");
        wait until transaction_count = 26 for 3 ms;
        wait until runtime_done = '1' for 1 ms;

        pulse_config("11", x"90");
        wait until transaction_count = 27 for 2 ms;
        wait until runtime_done = '1' for 1 ms;

        assert runtime_error = '0'
            report "ERROR: runtime_error durante escrituras con ACK" severity failure;
        report "[OK 3/4] Contraste, ganancia, exposicion y brillo verificados";

        report "[FASE 4/4] Inyectando NACK para comprobar propagacion de error";
        pulse_config("00", x"7F");
        wait until transaction_count = 28 for 2 ms;
        wait until runtime_error = '1' for 1 ms;
        assert runtime_error = '1'
            report "ERROR: runtime no informo el NACK" severity failure;
        assert i2c_ack_error = '1'
            report "ERROR: i2c_master no informo el NACK" severity failure;
        report "[OK 4/4] NACK detectado y propagado correctamente";

        report "============================================================";
        report "PASS_CAMERA_CONFIG_INTEGRATION: TODAS LAS PRUEBAS PASARON";
        report "============================================================";
        finish;
    end process;

    slave_model : process
        procedure wait_start_condition is
        begin
            wait until bus_bit(SDA) = '0' and bus_bit(SCL) = '1';
        end procedure;

        procedure receive_byte(variable value : out std_logic_vector(7 downto 0)) is
        begin
            for bit_index in 7 downto 0 loop
                wait until rising_edge(SCL);
                value(bit_index) := bus_bit(SDA);
            end loop;
        end procedure;

        procedure acknowledge is
        begin
            wait until falling_edge(SCL);
            sda_slave_drive <= '0';
            wait until rising_edge(SCL);
            wait until falling_edge(SCL);
            sda_slave_drive <= 'Z';
        end procedure;

        procedure reject_with_nack is
        begin
            wait until falling_edge(SCL);
            sda_slave_drive <= '1';
            wait until rising_edge(SCL);
            wait until falling_edge(SCL);
            sda_slave_drive <= 'Z';
        end procedure;

        procedure receive_write(
            expected_reg : std_logic_vector(7 downto 0);
            expected_data : std_logic_vector(7 downto 0);
            nack_data : boolean := false
        ) is
            variable value : std_logic_vector(7 downto 0);
        begin
            wait_start_condition;
            receive_byte(value);
            assert value = x"42" report "ERROR: direccion SCCB no es 0x42" severity failure;
            acknowledge;
            receive_byte(value);
            assert value = expected_reg report "ERROR: registro SCCB incorrecto" severity failure;
            acknowledge;
            receive_byte(value);
            assert value = expected_data report "ERROR: dato SCCB incorrecto" severity failure;
            if nack_data then
                reject_with_nack;
            else
                acknowledge;
            end if;
            transaction_count <= transaction_count + 1;
        end procedure;
    begin
        sda_slave_drive <= 'Z';
        wait until rst = '0';

        for index in EXPECTED_CONFIG'range loop
            receive_write(EXPECTED_CONFIG(index).reg_addr, EXPECTED_CONFIG(index).reg_data);
            assert init_current_step = to_unsigned(index, init_current_step'length)
                report "ERROR: current_step no coincide" severity failure;
        end loop;

        receive_write(x"56", x"60");
        receive_write(x"13", x"8B");
        receive_write(x"00", x"12");
        receive_write(x"13", x"8E");
        receive_write(x"10", x"34");
        receive_write(x"55", x"90");
        receive_write(x"56", x"7F", true);
        wait;
    end process;

    owner_monitor : process(clk)
    begin
        if rising_edge(clk) and i2c_runtime_owner = '1' then
            assert init_done = '0' or transaction_count >= 21
                report "ERROR: runtime obtuvo el bus antes del fin de init" severity failure;
        end if;
    end process;

    watchdog : process
    begin
        wait for 25 ms;
        assert false report "ERROR: timeout configuracion integrada" severity failure;
    end process;
end architecture;
