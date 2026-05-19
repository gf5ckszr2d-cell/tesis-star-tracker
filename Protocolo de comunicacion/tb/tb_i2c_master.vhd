library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2c_master is
end entity tb_i2c_master;

architecture sim of tb_i2c_master is

    component i2c_master is
        port (
            clk_i2c : in std_logic;
            rst     : in std_logic;
            start      : in std_logic;
            slave_addr : in std_logic_vector(6 downto 0);
            rw         : in std_logic;

            tx_byte0 : in std_logic_vector(7 downto 0);
            tx_byte1 : in std_logic_vector(7 downto 0);
            tx_count : in unsigned(1 downto 0);

            rx_data : out std_logic_vector(7 downto 0);

            SDA : inout std_logic;
            SCL : out std_logic;

            busy      : out std_logic;
            done      : out std_logic;
            ack_error : out std_logic
        );
    end component;

    signal clk_i2c   : std_logic := '0';
    signal rst       : std_logic := '1';
    signal start     : std_logic := '0';

    signal slave_addr : std_logic_vector(6 downto 0) := "0100001";
    signal rw         : std_logic := '0';

    signal tx_byte0 : std_logic_vector(7 downto 0) := x"15";
    signal tx_byte1 : std_logic_vector(7 downto 0) := x"02";
    signal tx_count : unsigned(1 downto 0) := "10";

    signal rx_data   : std_logic_vector(7 downto 0);
    signal busy      : std_logic;
    signal done      : std_logic;
    signal ack_error : std_logic;

    signal SDA : std_logic := 'H';
    signal SCL : std_logic;

    -- Driver del esclavo simulado:
    -- '0' = el esclavo baja SDA para ACK
    -- 'Z' = el esclavo suelta SDA
    signal sda_slave_drive : std_logic := 'Z';

    constant CLK_PERIOD : time := 20 ns;

    -- Convierte el valor físico del bus SDA a bit lógico.
    -- En simulación, cuando el bus está libre puede verse como 'H' por el pull-up.
    function sda_to_bit(signal_value : std_logic) return std_logic is
    begin
        if signal_value = '0' then
            return '0';
        else
            return '1';
        end if;
    end function;

begin

    --------------------------------------------------------------------
    -- Pull-up simulado del bus SDA
    --------------------------------------------------------------------
    SDA <= 'H';

    --------------------------------------------------------------------
    -- Driver del esclavo simulado
    --------------------------------------------------------------------
    SDA <= sda_slave_drive;

    --------------------------------------------------------------------
    -- Instancia del DUT
    --------------------------------------------------------------------
    uut : i2c_master
        port map (
            clk_i2c    => clk_i2c,
            rst        => rst,
            start      => start,
            slave_addr => slave_addr,
            rw         => rw,
            tx_byte0   => tx_byte0,
            tx_byte1   => tx_byte1,
            tx_count   => tx_count,
            rx_data    => rx_data,
            SDA        => SDA,
            SCL        => SCL,
            busy       => busy,
            done       => done,
            ack_error  => ack_error
        );

    --------------------------------------------------------------------
    -- Generador de reloj I2C para simulación
    --------------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk_i2c <= '0';
            wait for CLK_PERIOD / 2;
            clk_i2c <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Estímulos principales
    --------------------------------------------------------------------
    stimulus : process
    begin
        report "Inicio de simulacion del maestro I2C";

        rst   <= '1';
        start <= '0';
        wait for 2 * CLK_PERIOD;

        rst <= '0';
        wait until rising_edge(clk_i2c);

        report "Iniciando escritura: 0x42 -> 0x15 -> 0x02";

        start <= '1';
        wait until rising_edge(clk_i2c);
        start <= '0';

        wait until done = '1' for 5 us;

        assert done = '1'
            report "ERROR: timeout esperando done = 1"
            severity failure;

        wait until rising_edge(clk_i2c);

        assert ack_error = '0'
            report "ERROR: ack_error activo al final de la transaccion"
            severity failure;

        assert busy = '0'
            report "ERROR: busy no regreso a 0 al finalizar la transaccion"
            severity failure;

        report "Transaccion I2C finalizada correctamente sin errores";

        wait;
    end process;

    --------------------------------------------------------------------
    -- Esclavo simulado simple
    --------------------------------------------------------------------
    slave_model : process
        type byte_array_t is array (0 to 2) of std_logic_vector(7 downto 0);

        constant expected_bytes : byte_array_t := (
            0 => x"42", -- slave_addr & write
            1 => x"15", -- registro COM10
            2 => x"02"  -- dato a escribir en COM10
        );

        variable received_byte : std_logic_vector(7 downto 0);
    begin
        sda_slave_drive <= 'Z';

        -- Esperar a que termine el reset
        wait until rst = '0';

        -- Esperar START:
        -- SDA baja mientras SCL está alto
        wait until SDA = '0' and SCL = '1';

        report "Esclavo simulado detecto START";

        ----------------------------------------------------------------
        -- Recibir los 3 bytes esperados:
        -- 1) x42
        -- 2) x15
        -- 3) x02
        ----------------------------------------------------------------
        for byte_index in 0 to 2 loop

            received_byte := (others => '0');

            -- Leer 8 bits, MSB primero
            for bit_index in 7 downto 0 loop
                wait until rising_edge(SCL);
                received_byte(bit_index) := sda_to_bit(SDA);
            end loop;

            assert received_byte = expected_bytes(byte_index)
                report "ERROR: byte recibido no coincide con el esperado"
                severity failure;

            report "Byte recibido correctamente por el esclavo simulado";

            ------------------------------------------------------------
            -- ACK:
            -- Después de los 8 bits, el maestro baja SCL y libera SDA.
            -- El esclavo baja SDA durante el noveno pulso de SCL.
            ------------------------------------------------------------
            wait until falling_edge(SCL);

            sda_slave_drive <= '0';  -- ACK

            wait until rising_edge(SCL);
            wait until falling_edge(SCL);

            sda_slave_drive <= 'Z';  -- soltar SDA después del ACK

        end loop;

        report "Esclavo simulado recibio correctamente x42, x15 y x02";

        wait;
    end process;

end architecture sim;
