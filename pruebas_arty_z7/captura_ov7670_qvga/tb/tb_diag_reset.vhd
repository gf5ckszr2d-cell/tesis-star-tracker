library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_diag_reset is end;
architecture sim of tb_diag_reset is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start, reset_btn, tx : std_logic := '0';
    signal led : std_logic_vector(3 downto 0);
    signal software_control : std_logic_vector(63 downto 0) := (others=>'0');
begin
    clk <= not clk after 5 ns;
    dut : entity work.captura_uart_top
        generic map(DEBOUNCE_CYCLES=>4, POWERUP_CYCLES=>100)
        port map(clk=>clk,rst=>rst,start=>start,reset_btn=>reset_btn,diag_led=>led,
            capture_status=>open,
            software_control=>software_control,
            tx=>tx,sda_i=>'1',sda_t=>open,SCL=>open,cam_xclk=>open,cam_pclk=>'0',
            cam_vsync=>'0',cam_href=>'0',cam_data=>x"00",cam_pwdn=>open,cam_reset=>open);
    stimulus : process
    begin
        wait for 500 ns; rst<='0'; wait for 10 us;
        start<='1'; wait for 1 us; start<='0'; wait for 200 us;
        assert led(3 downto 1)="001" and tx='1'
            report "Camera NACK did not show LED code 001 / quiet UART" severity failure;
        reset_btn<='1'; wait for 1 us; reset_btn<='0'; wait for 10 us;
        assert led(3 downto 1)="000" and tx='1'
            report "BTN0 did not recover core without PCLK" severity failure;
        software_control(0)<='1'; wait for 1 us; software_control(0)<='0'; wait for 200 us;
        assert led(3 downto 1)="001" report "Software retry after BTN0 failed" severity failure;
        report "PASS_DIAG_RESET: SCCB NACK LED code, no UART, BTN0/retry without PCLK";
        finish;
    end process;
end;
