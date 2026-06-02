library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity ov7670_xclk_gen is
    port (
        clk_100mhz : in std_logic;
        rst        : in std_logic;

        xclk   : out std_logic;
        locked : out std_logic
    );
end entity;

architecture rtl of ov7670_xclk_gen is

    signal clkfb     : std_logic;
    signal clkfb_buf : std_logic;
    signal xclk_mmcm : std_logic;

begin

    u_mmcm : MMCME2_BASE
        generic map (
            BANDWIDTH          => "OPTIMIZED",
            CLKFBOUT_MULT_F    => 12.0,
            CLKFBOUT_PHASE     => 0.0,
            CLKIN1_PERIOD      => 10.0,
            CLKOUT0_DIVIDE_F   => 50.0,
            CLKOUT0_DUTY_CYCLE => 0.5,
            CLKOUT0_PHASE      => 0.0,
            DIVCLK_DIVIDE      => 1,
            REF_JITTER1        => 0.01,
            STARTUP_WAIT       => false
        )
        port map (
            CLKIN1   => clk_100mhz,
            CLKFBIN  => clkfb_buf,
            CLKFBOUT => clkfb,

            CLKOUT0 => xclk_mmcm,
            CLKOUT0B => open,
            CLKOUT1 => open,
            CLKOUT1B => open,
            CLKOUT2 => open,
            CLKOUT2B => open,
            CLKOUT3 => open,
            CLKOUT3B => open,
            CLKOUT4 => open,
            CLKOUT5 => open,
            CLKOUT6 => open,

            LOCKED => locked,
            PWRDWN => '0',
            RST    => rst
        );

    u_clkfb_buf : BUFG
        port map (
            I => clkfb,
            O => clkfb_buf
        );

    u_xclk_buf : BUFG
        port map (
            I => xclk_mmcm,
            O => xclk
        );

end architecture;
