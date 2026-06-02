library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity framebuffer_y_bram is
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
end entity;

architecture rtl of framebuffer_y_bram is

    type ram_t is array (0 to FRAME_PIXELS - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal ram : ram_t := (others => (others => '0'));

    signal rd_data_reg : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

begin

    rd_data <= rd_data_reg;

    process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if wr_en = '1' then
                if to_integer(wr_addr) < FRAME_PIXELS then
                    ram(to_integer(wr_addr)) <= wr_data;
                end if;
            end if;
        end if;
    end process;

    process(rd_clk)
    begin
        if rising_edge(rd_clk) then
            if to_integer(rd_addr) < FRAME_PIXELS then
                rd_data_reg <= ram(to_integer(rd_addr));
            else
                rd_data_reg <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
