library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_sccb_runtime is end;
architecture sim of tb_sccb_runtime is
    signal clk : std_logic:='0';
    signal rst : std_logic:='1';
    signal available, active, go, rw, busy, done, err : std_logic:='0';
    signal control : std_logic_vector(63 downto 0):=(others=>'0');
    signal status : std_logic_vector(31 downto 0);
    signal b0,b1 : std_logic_vector(7 downto 0);
    signal n : unsigned(1 downto 0);
    signal operations : natural:=0;
begin
    clk<=not clk after 5 ns;
    dut: entity work.sccb_runtime_bridge port map(clk,rst,available,control,status,
        active,go,rw,b0,b1,n,busy,done,err,x"A5");
    model: process
    begin
        wait until rising_edge(clk) and go='1';
        busy<='1'; operations<=operations+1;
        assert b0=x"10" report "Register not latched" severity failure;
        if rw='0' then
            if operations=0 then
                assert n=2 and b1=x"AB" severity failure;
            else assert n=1 report "Read needs pointer write" severity failure; end if;
        else assert operations=2 report "Read order" severity failure; end if;
        wait for 100 ns; done<='1'; wait until rising_edge(clk);
        done<='0'; wait until rising_edge(clk); busy<='0';
    end process;
    stimulus: process
    begin
        wait for 40 ns; rst<='0';
        control(1)<='1'; wait for 100 ns;
        assert status(0)='1' and status(3)='1' and operations=0
            report "Unavailable command must reject" severity failure;
        available<='1'; control(15 downto 8)<=x"10"; control(23 downto 16)<=x"AB";
        control(1)<='0'; wait for 250 ns;
        assert status(0)='0' and status(3 downto 1)="000" and status(15 downto 8)=x"AB" severity failure;
        wait for 100 ns;
        assert operations=1 report "Held request repeated" severity failure;
        control(2)<='1'; control(1)<='1'; wait for 450 ns;
        assert status(0)='1' and status(3 downto 1)="000" and status(15 downto 8)=x"A5" and operations=3
            report "Pointer/read result" severity failure;
        err<='1'; control(1)<='0'; wait for 250 ns;
        assert status(0)='0' and status(2)='1' and operations=4 report "Pointer NACK" severity failure;
        report "PASS_SCCB_RUNTIME: reject, write, pointer/read, held request, NACK";
        finish;
    end process;
end;
