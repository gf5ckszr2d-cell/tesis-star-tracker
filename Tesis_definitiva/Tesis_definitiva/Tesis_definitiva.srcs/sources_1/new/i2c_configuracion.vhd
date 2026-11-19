
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity i2c_configuracion is
    generic (
        CLK_FREQ_HZ : integer := 125000000
    );
    port (
        clk   : in std_logic;
        rst   : in std_logic;
        start : in std_logic;

        SCL : out std_logic;
        SDA : inout std_logic;

        busy        : out std_logic;
        done        : out std_logic;
        error       : out std_logic;
        paso_actual : out unsigned(4 downto 0)
    );
end entity;

architecture rtl of i2c_configuracion is

    signal i2c_inicio   : std_logic;
    signal i2c_lectura  : std_logic;
    signal i2c_dato1    : std_logic_vector(7 downto 0);
    signal i2c_dato2    : std_logic_vector(7 downto 0);
    signal i2c_cantidad : unsigned(1 downto 0);

    signal i2c_terminado : std_logic;
    signal i2c_error     : std_logic;

    signal sda_entrada : std_logic;
    signal sda_liberar : std_logic;

begin

    IOBUF_sda : IOBUF
        port map (
            I  => '0',
            T  => sda_liberar,
            O  => sda_entrada,
            IO => SDA
        );

    configurar_camara : entity work.ov7670_init_config
        generic map (
            CLK_FREQ_HZ    => CLK_FREQ_HZ,
            RESET_DELAY_MS => 1
        )
        port map (
            clk   => clk,
            rst   => rst,
            start => start,

            i2c_done      => i2c_terminado,
            i2c_ack_error => i2c_error,

            i2c_start        => i2c_inicio,
            i2c_rw           => i2c_lectura,
            i2c_dato1        => i2c_dato1,
            i2c_dato2        => i2c_dato2,
            i2c_cuenta_datos => i2c_cantidad,

            busy        => busy,
            done        => done,
            error       => error,
            paso_actual => paso_actual
        );

    maestro_i2c : entity work.i2c_master
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            I2C_SCL_HZ  => 100000
        )
        port map (
            clk => clk,
            rst => rst,

            start      => i2c_inicio,
            slave_addr => "0100001",
            rw         => i2c_lectura,

            dato1        => i2c_dato1,
            dato2        => i2c_dato2,
            cuenta_datos => i2c_cantidad,

            rx_data => open,

            sda_i => sda_entrada,
            sda_t => sda_liberar,
            SCL   => SCL,

            busy      => open,
            done      => i2c_terminado,
            ack_error => i2c_error
        );

end architecture;
