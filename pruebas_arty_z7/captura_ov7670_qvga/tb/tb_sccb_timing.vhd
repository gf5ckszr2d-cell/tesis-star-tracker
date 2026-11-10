library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_sccb_timing is end;
architecture sim of tb_sccb_timing is
    constant TEST_DATA : std_logic_vector(7 downto 0) := x"A5";
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start, rw, sda_t, scl, done, err : std_logic := '0';
    signal sda : std_logic := 'H';
    signal slave : std_logic := 'Z';
    signal rx : std_logic_vector(7 downto 0);
begin
    clk <= not clk after 50 ns;
    sda <= 'H'; sda <= slave; sda <= '0' when sda_t='0' else 'Z';
    dut : entity work.i2c_master
        generic map(CLK_FREQ_HZ=>10000000, I2C_SCL_HZ=>100000)
        port map(clk=>clk,rst=>rst,start=>start,slave_addr=>"0100001",rw=>rw,
            tx_byte0=>x"12",tx_byte1=>x"80",tx_count=>to_unsigned(2,2),
            rx_data=>rx,sda_i=>to_x01(sda),sda_t=>sda_t,SCL=>scl,busy=>open,done=>done,ack_error=>err);
    stimulus : process
    begin
        wait for 1 us; rst<='0'; wait for 1 us;
        start<='1'; wait for 200 ns; start<='0';
        wait until done='1' for 1 ms;
        assert done='1' and err='0' report "Delayed ACK write failed" severity failure;
        wait for 20 us;
        rw<='1'; start<='1'; wait for 200 ns; start<='0';
        wait until done='1' for 1 ms;
        assert done='1' and err='0' and rx=x"A5" report "Read data sampling failed" severity failure;
        wait for 20 us;
        rw<='0'; start<='1'; wait for 200 ns; start<='0';
        wait until done='1' for 1 ms;
        assert done='1' and err='1' report "Missing slave did not NACK" severity failure;
        report "PASS_SCCB_TIMING: write/address, delayed ACK, read A5, NACK";
        finish;
    end process;
    sensor : process
        procedure receive_byte(expected : std_logic_vector(7 downto 0)) is
            variable b : std_logic_vector(7 downto 0);
        begin
            for i in 7 downto 0 loop
                wait until rising_edge(scl); b(i):=to_x01(sda);
            end loop;
            assert b=expected report "Unexpected SCCB byte" severity failure;
        end;
        procedure ack is
        begin
            wait until falling_edge(scl);
            -- Deliberately late relative to SCL rising to detect old same-cycle sampler.
            wait until rising_edge(scl); wait for 100 ns; slave<='0';
            wait until falling_edge(scl); slave<='Z';
        end;
    begin
        wait until falling_edge(sda) and scl='1';
        receive_byte(x"42"); ack;
        receive_byte(x"12"); ack;
        receive_byte(x"80"); ack;
        wait until rising_edge(sda) and scl='1';
        wait until falling_edge(sda) and scl='1';
        receive_byte(x"43"); ack;
        for i in 7 downto 0 loop
            -- ack returns at the falling edge for the first data bit.
            wait for 100 ns;
            if TEST_DATA(i)='0' then slave<='0'; else slave<='Z'; end if;
            wait until rising_edge(scl);
            wait until falling_edge(scl);
        end loop;
        slave<='Z';
        wait until rising_edge(scl);
        assert to_x01(sda)='1' report "Master did not send final NACK" severity failure;
        wait;
    end process;
    watchdog : process begin wait for 4 ms; assert false report "SCCB timeout" severity failure; end process;
end;
