library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

-- Prueba de los defaults reales de 100 MHz, sin acelerar baud ni MMCM.
entity tb_relojes_100 is end entity;
architecture sim of tb_relojes_100 is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start : std_logic := '0';
    signal xclk, locked, scl, tx, tx_done : std_logic;
    signal sda : std_logic := 'H';
    signal xclk_ok, sccb_ok, uart_ok : boolean := false;
begin
    clk <= not clk after 5 ns;
    sda <= 'H';
    -- Sin generic map: comprobar precisamente los nuevos valores por defecto.
    clock_camera : entity work.captura_xclk
        port map (clk => clk, rst => rst, xclk => xclk, locked => locked);
    control_camera : entity work.i2c_master
        port map (clk => clk, rst => rst, start => start, slave_addr => "0100001",
            rw => '0', tx_byte0 => x"13", tx_byte1 => x"8F",
            tx_count => to_unsigned(2, 2), rx_data => open, sda_i => to_x01(sda), sda_t => open,
            SCL => scl, busy => open, done => open, ack_error => open);
    serial : entity work.uart_tx
        generic map (BAUD_RATE => 921600) -- same explicit value as captura_uart_top/BD
        port map (clk => clk, rst => rst, tx_start => start, tx_data => x"55",
            tx_line => tx, busy => open, done => tx_done);
    stimulus : process
    begin
        wait for 200 ns;
        wait until falling_edge(clk); rst <= '0';
        wait until falling_edge(clk); start <= '1';
        wait until falling_edge(clk); start <= '0';
        wait until xclk_ok and sccb_ok and uart_ok for 200 us;
        assert xclk_ok and sccb_ok and uart_ok report "Timeout de relojes" severity failure;
        report "PASS_RELOJES_100: entrada 100 MHz, XCLK 24 MHz, SCL 100 kHz, UART 108 ciclos/bit";
        finish;
    end process;
    check_xclk : process
        variable previous : time;
    begin
        wait until locked = '1';
        wait until rising_edge(xclk);
        for i in 1 to 20 loop
            previous := now;
            wait until rising_edge(xclk);
            assert abs((now-previous)-41.667 ns) < 10 ps
                report "XCLK incorrecto" severity failure;
        end loop;
        xclk_ok <= true;
        wait;
    end process;
    check_sccb : process
        variable previous : time;
    begin
        wait until rst = '0';
        wait until rising_edge(scl);
        for i in 1 to 3 loop
            previous := now;
            wait until rising_edge(scl);
            assert now-previous = 10 us report "SCL no es 100 kHz" severity failure;
        end loop;
        sccb_ok <= true;
        wait;
    end process;
    check_uart : process
        variable previous : time;
    begin
        wait until rst = '0';
        wait until falling_edge(tx);
        for i in 1 to 9 loop
            previous := now;
            wait on tx;
            assert now-previous = 1080 ns
                report "UART no usa 108 ciclos de 10 ns por bit" severity failure;
        end loop;
        wait until tx_done = '1';
        uart_ok <= true;
        wait;
    end process;
end architecture;
