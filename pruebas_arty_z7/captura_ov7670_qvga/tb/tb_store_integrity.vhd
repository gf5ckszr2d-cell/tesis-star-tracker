library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_store_integrity is end;
architecture sim of tb_store_integrity is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal arm, released, valid, done, invalid, ready, toggle, err : std_logic := '0';
    signal x,y : unsigned(9 downto 0) := (others=>'0');
begin
    clk <= not clk after 5 ns;
    dut : entity work.frame_capture_store
        generic map(FRAME_WIDTH=>4,FRAME_HEIGHT=>3)
        port map(pclk=>clk,rst=>rst,arm_capture=>arm,dump_done_toggle=>released,
            pixel_y=>x"80",pixel_valid=>valid,pixel_x=>x,pixel_y_pos=>y,frame_done=>done,
            capture_invalid=>invalid,wr_en=>open,wr_addr=>open,wr_data=>open,
            capture_busy=>open,frame_ready=>ready,frame_ready_toggle=>toggle,overflow=>err);
    stimulus : process
        procedure cycle is begin wait until falling_edge(clk); end;
        procedure arm_frame is begin arm<='1'; cycle; arm<='0'; cycle; end;
        procedure pixels(n : natural) is
        begin
            for i in 0 to n-1 loop
                x<=to_unsigned(i mod 4,10); y<=to_unsigned(i/4,10); valid<='1'; cycle;
            end loop;
            valid<='0'; cycle;
        end;
        procedure finish_frame is begin done<='1'; cycle; done<='0'; cycle; end;
        procedure reset is begin rst<='1'; cycle; rst<='0'; cycle; end;
    begin
        cycle; reset;
        arm_frame; pixels(12); finish_frame;
        assert ready='1' and toggle='1' and err='0' report "Full frame rejected" severity failure;
        released<='1'; cycle; cycle;
        assert ready='0' severity failure;
        arm_frame; pixels(5); finish_frame;
        assert ready='0' and toggle='1' and err='1' report "Short frame accepted" severity failure;
        reset;
        arm_frame; pixels(12); invalid<='1'; finish_frame;
        assert ready='0' and toggle='0' and err='1' report "Capture overflow accepted" severity failure;
        invalid<='0'; reset;
        arm_frame; pixels(4); pixels(4); finish_frame;
        assert ready='0' and err='1' report "Duplicate coordinates accepted" severity failure;
        report "PASS_STORE_INTEGRITY: full/release, short, invalid and duplicate frames";
        finish;
    end process;
end;
