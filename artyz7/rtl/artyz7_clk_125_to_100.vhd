library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity artyz7_clk_125_to_100 is
    port (
        clk_125mhz : in std_logic;
        rst        : in std_logic;

        clk_100mhz : out std_logic;
        locked     : out std_logic
    );
end entity;

architecture rtl of artyz7_clk_125_to_100 is

    signal clkfb       : std_logic;
    signal clkfb_buf   : std_logic;
    signal clk100_mmcm : std_logic;

begin

    u_mmcm : MMCME2_BASE
        generic map (
            BANDWIDTH          => "OPTIMIZED",
            CLKFBOUT_MULT_F    => 8.0,
            CLKFBOUT_PHASE     => 0.0,
            CLKIN1_PERIOD      => 8.0,
            CLKOUT0_DIVIDE_F   => 10.0,
            CLKOUT0_DUTY_CYCLE => 0.5,
            CLKOUT0_PHASE      => 0.0,
            DIVCLK_DIVIDE      => 1,
            REF_JITTER1        => 0.01,
            STARTUP_WAIT       => false
        )
        port map (
            CLKIN1   => clk_125mhz,
            CLKFBIN  => clkfb_buf,
            CLKFBOUT => clkfb,

            CLKOUT0  => clk100_mmcm,
            CLKOUT0B => open,
            CLKOUT1  => open,
            CLKOUT1B => open,
            CLKOUT2  => open,
            CLKOUT2B => open,
            CLKOUT3  => open,
            CLKOUT3B => open,
            CLKOUT4  => open,
            CLKOUT5  => open,
            CLKOUT6  => open,

            LOCKED => locked,
            PWRDWN => '0',
            RST    => rst
        );

    u_clkfb_buf : BUFG
        port map (
            I => clkfb,
            O => clkfb_buf
        );

    u_clk100_buf : BUFG
        port map (
            I => clk100_mmcm,
            O => clk_100mhz
        );

end architecture;

