library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_framebuffer_y_bram is
end entity;

architecture sim of tb_framebuffer_y_bram is

    component framebuffer_y_bram is
        generic (
            ADDR_WIDTH   : integer := 15;
            DATA_WIDTH   : integer := 8;
            FRAME_PIXELS : integer := 19200
        );
        port (
            wr_clk  : in std_logic;
            wr_en   : in std_logic;
            wr_addr : in unsigned(ADDR_WIDTH - 1 downto 0);
            wr_data : in std_logic_vector(DATA_WIDTH - 1 downto 0);

            rd_clk  : in std_logic;
            rd_addr : in unsigned(ADDR_WIDTH - 1 downto 0);
            rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component;

    constant ADDR_WIDTH : integer := 4;
    constant WR_PERIOD  : time := 40 ns;
    constant RD_PERIOD  : time := 10 ns;

    signal wr_clk  : std_logic := '0';
    signal wr_en   : std_logic := '0';
    signal wr_addr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal wr_data : std_logic_vector(7 downto 0) := (others => '0');

    signal rd_clk  : std_logic := '0';
    signal rd_addr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_data : std_logic_vector(7 downto 0);

begin

    uut : framebuffer_y_bram
        generic map (
            ADDR_WIDTH   => ADDR_WIDTH,
            DATA_WIDTH   => 8,
            FRAME_PIXELS => 8
        )
        port map (
            wr_clk  => wr_clk,
            wr_en   => wr_en,
            wr_addr => wr_addr,
            wr_data => wr_data,

            rd_clk  => rd_clk,
            rd_addr => rd_addr,
            rd_data => rd_data
        );

    wr_clk_process : process
    begin
        while true loop
            wr_clk <= '0';
            wait for WR_PERIOD / 2;
            wr_clk <= '1';
            wait for WR_PERIOD / 2;
        end loop;
    end process;

    rd_clk_process : process
    begin
        while true loop
            rd_clk <= '0';
            wait for RD_PERIOD / 2;
            rd_clk <= '1';
            wait for RD_PERIOD / 2;
        end loop;
    end process;

    stimulus : process
    begin
        report "Inicio de simulacion framebuffer_y_bram";

        wait until rising_edge(wr_clk);
        wr_en <= '1';
        wr_addr <= to_unsigned(0, ADDR_WIDTH);
        wr_data <= x"11";
        wait until rising_edge(wr_clk);
        wr_addr <= to_unsigned(1, ADDR_WIDTH);
        wr_data <= x"22";
        wait until rising_edge(wr_clk);
        wr_addr <= to_unsigned(7, ADDR_WIDTH);
        wr_data <= x"77";
        wait until rising_edge(wr_clk);
        wr_en <= '0';

        wait until rising_edge(rd_clk);
        rd_addr <= to_unsigned(0, ADDR_WIDTH);
        wait until rising_edge(rd_clk);
        wait for 1 ns;
        assert rd_data = x"11"
            report "ERROR: dato en direccion 0 no coincide"
            severity failure;

        rd_addr <= to_unsigned(1, ADDR_WIDTH);
        wait until rising_edge(rd_clk);
        wait for 1 ns;
        assert rd_data = x"22"
            report "ERROR: dato en direccion 1 no coincide"
            severity failure;

        rd_addr <= to_unsigned(7, ADDR_WIDTH);
        wait until rising_edge(rd_clk);
        wait for 1 ns;
        assert rd_data = x"77"
            report "ERROR: dato en direccion 7 no coincide"
            severity failure;

        report "Simulacion framebuffer_y_bram finalizada correctamente";
        wait;
    end process;

end architecture;
