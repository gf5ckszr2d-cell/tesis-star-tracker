library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity captura_xclk is
    generic (CLK_FREQ_HZ : positive := 100000000);
    port (
        clk : in std_logic;
        rst        : in std_logic;

        xclk   : out std_logic;
        locked : out std_logic
    );
end entity;

architecture rtl of captura_xclk is

    function mult return real is
    begin
        if CLK_FREQ_HZ = 125000000 then return 48.0; else return 12.0; end if;
    end function;
    function divclk return integer is
    begin
        if CLK_FREQ_HZ = 125000000 then return 5; else return 1; end if;
    end function;
    signal clkfb     : std_logic;
    signal clkfb_buf : std_logic;
    signal xclk_mmcm : std_logic;

begin
    assert CLK_FREQ_HZ = 100000000 or CLK_FREQ_HZ = 125000000
        report "Solo se admiten relojes de 100 MHz o 125 MHz" severity failure;

    u_mmcm : MMCME2_BASE
        generic map (
            BANDWIDTH          => "OPTIMIZED",
            CLKFBOUT_MULT_F    => mult,
            CLKFBOUT_PHASE     => 0.0,
            CLKIN1_PERIOD      => 1.0e9 / real(CLK_FREQ_HZ),
            CLKOUT0_DIVIDE_F   => 50.0,
            CLKOUT0_DUTY_CYCLE => 0.5,
            CLKOUT0_PHASE      => 0.0,
            DIVCLK_DIVIDE      => divclk,
            REF_JITTER1        => 0.01,
            STARTUP_WAIT       => false
        )
        port map (
            CLKIN1   => clk,
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
