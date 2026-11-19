library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2c_master is
end entity;

architecture sim of tb_i2c_master is

  constant CLK_FREQ_HZ : integer := 125000000;
  constant I2C_SCL_HZ  : integer := 100000;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal start      : std_logic := '0';
  signal slave_addr : std_logic_vector(6 downto 0) := "0100001";
  signal rw         : std_logic := '0';

  signal dato1 : std_logic_vector(7 downto 0) := x"12";
  signal dato2 : std_logic_vector(7 downto 0) := x"80";

  signal cuenta_datos : unsigned(1 downto 0) := to_unsigned(2, 2);

  signal rx_data : std_logic_vector(7 downto 0);

  signal sda_i : std_logic;
  signal sda_t : std_logic;
  signal SCL   : std_logic;

  signal sda : std_logic := '1';
  signal camara_baja_sda : std_logic := '0';

  signal busy      : std_logic;
  signal done      : std_logic;
  signal ack_error : std_logic;

  signal stop_visto : std_logic := '0';

begin

  -- Reloj de 125 MHz
  clk <= not clk after 4 ns;

  -- SDA compartida entre FPGA y camara
  -- Si nadie la baja, queda en HIGH
  sda <= '0' when (sda_t = '0' or camara_baja_sda = '1')
         else '1';

  sda_i <= sda;

  -- Maestro I2C
  uut : entity work.i2c_master
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      I2C_SCL_HZ  => I2C_SCL_HZ
    )
    port map (
      clk => clk,
      rst => rst,

      start      => start,
      slave_addr => slave_addr,
      rw         => rw,

      dato1        => dato1,
      dato2        => dato2,
      cuenta_datos => cuenta_datos,

      rx_data => rx_data,

      sda_i => sda_i,
      sda_t => sda_t,
      SCL   => SCL,

      busy      => busy,
      done      => done,
      ack_error => ack_error
    );

  -- Iniciar una escritura
  prueba : process
  begin

    wait for 100 ns;
    wait until rising_edge(clk);
    rst <= '0';

    wait until rising_edge(clk);
    start <= '1';

    wait until rising_edge(clk);
    start <= '0';

    -- Esperar a que termine la escritura
    wait until done = '1' for 500 us;

    assert done = '1'
      report "ERROR: El maestro no termino"
      severity failure;

    assert ack_error = '0'
      report "ERROR: El maestro detecto un problema con ACK"
      severity failure;

    -- Comprobar que tambien genero STOP
    wait until stop_visto = '1' for 20 us;

    assert stop_visto = '1'
      report "ERROR: No se detecto STOP"
      severity failure;

    report "PRUEBA CORRECTA: Escritura terminada";
    wait;

  end process;

  -- Simulacion de la OV7670
  camara : process

    type datos_t is array (0 to 2)
      of std_logic_vector(7 downto 0);

    constant esperados : datos_t := (
      x"42",  -- Direccion de escritura
      x"12",  -- Registro
      x"80"   -- Dato
    );

    variable dato_leido : std_logic_vector(7 downto 0);

  begin

    camara_baja_sda <= '0';

    -- Esperar START
    wait until sda = '0' and SCL = '1';

    report "START detectado";

    -- Recibir los tres bytes
    for numero in 0 to 2 loop

      -- Leer 8 bits
      for bit_num in 7 downto 0 loop

        wait until rising_edge(SCL);
        dato_leido(bit_num) := sda;

      end loop;

      -- Verificar el byte recibido
      assert dato_leido = esperados(numero)
        report "ERROR: Byte recibido incorrecto"
        severity failure;

      report "Byte recibido correctamente: "
             & integer'image(numero);

      -- Esperar que SCL baje para preparar ACK
      wait until falling_edge(SCL);

      -- La camara responde ACK = 0
      camara_baja_sda <= '1';

      -- Noveno pulso: ACK
      wait until rising_edge(SCL);

      assert sda = '0'
        report "ERROR: SDA no esta en LOW durante ACK"
        severity failure;

      report "ACK enviado";

      -- Termina el pulso ACK
      wait until falling_edge(SCL);

      -- La camara libera SDA
      camara_baja_sda <= '0';

    end loop;

    -- Esperar STOP
    wait until rising_edge(SCL);
    wait until sda = '1';

    assert SCL = '1'
      report "ERROR: STOP incorrecto"
      severity failure;

    stop_visto <= '1';
    report "STOP detectado";

    wait;

  end process;

  -- Medir los pulsos HIGH de SCL
  medir_scl : process

    variable tiempo_subida : time;

  begin

    -- Esperar START
    wait until sda = '0' and SCL = '1';

    -- 3 bytes: 8 bits + 1 ACK cada uno
    for pulso in 1 to 27 loop

      wait until rising_edge(SCL);
      tiempo_subida := now;

      wait until falling_edge(SCL);

      assert now - tiempo_subida = 5 us
        report "ERROR: Duracion HIGH de SCL diferente de 5 us"
        severity error;

    end loop;

    report "Duracion HIGH de los 27 pulsos verificada";
    wait;

  end process;

end architecture;
