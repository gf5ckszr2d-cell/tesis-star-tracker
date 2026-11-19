library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_capture_blanking is end;
architecture sim of tb_capture_blanking is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal enable, vsync, href, valid, done, overflow : std_logic := '0';
    signal data, pixel : std_logic_vector(7 downto 0) := x"00";
    signal x,y : unsigned(9 downto 0);
    signal count : natural := 0;
begin
    clk <= not clk after 20 ns;
    dut : entity work.ov7670_capture_y_stream
        generic map(FRAME_WIDTH=>4, FRAME_HEIGHT=>3)
        port map(pclk=>clk,rst=>rst,enable=>enable,vsync=>vsync,href=>href,data=>data,
            pixel_y=>pixel,pixel_valid=>valid,pixel_x=>x,pixel_y_pos=>y,
            frame_active=>open,frame_done=>done,overflow=>overflow);
    check : process(clk)
    begin
        if rising_edge(clk) and valid='1' then
            assert to_integer(x)=count mod 4 and to_integer(y)=count/4
                report "Phantom row at VSYNC boundary" severity failure;
            count <= count+1;
        end if;
    end process;
    stimulus : process
        procedure step is begin wait until falling_edge(clk); end;
    begin
        step; rst<='0'; enable<='1'; step;
        vsync<='1'; href<='1'; step; step; step;
        -- HREF was active during vertical blanking and falls with VSYNC.
        -- It must not close an image line or shift row numbering.
        vsync<='0'; href<='0'; step; step;
        assert overflow='0' report "False 010: blanking HREF counted as a zero-length image line" severity failure;
        for row in 0 to 2 loop
            href<='1';
            for b in 0 to 7 loop data<=std_logic_vector(to_unsigned(b,8)); step; end loop;
            href<='0'; step; step;
        end loop;
        vsync<='1'; step; step;
        assert count=12 and overflow='0' report "Valid image after blanking rejected" severity failure;
        report "PASS_CAPTURE_BLANKING: HREF inside VSYNC ignored, first row 0, all 12 pixels";
        finish;
    end process;
end;
