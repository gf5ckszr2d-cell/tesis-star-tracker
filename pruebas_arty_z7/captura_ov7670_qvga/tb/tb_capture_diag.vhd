library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_capture_diag is end;
architecture sim of tb_capture_diag is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal en,vs,hr,pv,done,caperr,storeerr : std_logic := '0';
    signal status : std_logic_vector(63 downto 0);
begin
    clk <= not clk after 20 ns;
    dut : entity work.capture_frame_diag
        generic map(FRAME_WIDTH=>4,FRAME_HEIGHT=>3)
        port map(pclk=>clk,rst=>rst,enable=>en,vsync=>vs,href=>hr,pixel_valid=>pv,
            frame_done=>done,capture_error=>caperr,store_error=>storeerr,status=>status);
    stimulus : process
        procedure step is begin wait until falling_edge(clk); end;
        procedure begin_frame is
        begin
            en<='0'; step; step; en<='1'; vs<='0'; step;
            vs<='1'; hr<='1'; step; step; -- dummy HREF inside VSYNC
            vs<='0'; hr<='0'; step; step;
        end;
        procedure line(n : positive) is
        begin
            hr<='1';
            for i in 0 to n-1 loop
                if i mod 2=0 then pv<='1'; else pv<='0'; end if;
                step;
            end loop;
            hr<='0'; pv<='0'; step; step;
        end;
        procedure finish_frame(reason, expected_lines, min_b, max_b, px, bad : natural) is
        begin
            vs<='1'; step; done<='1'; step; done<='0'; step; step; step;
            assert status(63)='1' and to_integer(unsigned(status(3 downto 0)))=reason
                report "Diagnostic reason mismatch" severity failure;
            assert to_integer(unsigned(status(11 downto 4)))=expected_lines
                and to_integer(unsigned(status(23 downto 12)))=min_b
                and to_integer(unsigned(status(35 downto 24)))=max_b
                and to_integer(unsigned(status(51 downto 36)))=px
                and to_integer(unsigned(status(59 downto 52)))=bad
                report "Diagnostic counters mismatch" severity failure;
        end;
    begin
        step; rst<='0'; step;
        begin_frame; line(8); line(8); line(8); finish_frame(0,3,8,8,12,255);
        begin_frame; line(8); line(6); line(8); finish_frame(1,3,6,8,11,1);
        begin_frame; line(10); line(8); line(8); finish_frame(2,3,8,10,13,0);
        begin_frame; line(7); line(8); line(8); finish_frame(3,3,7,8,12,0);
        begin_frame; line(8); line(8); finish_frame(4,2,8,8,8,255);
        begin_frame; line(8); line(8); line(8); line(8); finish_frame(5,4,8,8,16,255);
        begin_frame; line(8); line(8); line(8); storeerr<='1'; finish_frame(7,3,8,8,12,255);
        storeerr<='0';
        begin_frame; line(8); line(8); line(8); caperr<='1'; finish_frame(8,3,8,8,12,255);
        report "PASS_CAPTURE_DIAG: counts, ignored blanking, short/long/odd/rows/store/capture reasons";
        finish;
    end process;
end;
