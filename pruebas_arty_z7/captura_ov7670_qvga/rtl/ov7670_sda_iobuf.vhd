
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity ov7670_sda_iobuf is
    port (
        sda_i : out std_logic;
        sda_t : in  std_logic;
        SDA   : inout std_logic
    );
end entity;

architecture rtl of ov7670_sda_iobuf is
begin

    u_sda_buffer : IOBUF
        port map (
            I  => '0',
            O  => sda_i,
            T  => sda_t,
            IO => SDA
        );

end architecture;
