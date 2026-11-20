library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.attitude_math_pkg.all;

entity enviar_actitud_uart is
  port (
    clk, reset, iniciar, valido : in std_logic;
    cantidad : in unsigned(3 downto 0);
    foto : in unsigned(31 downto 0);
    q : in vec4_t;
    uart_busy, uart_done : in std_logic;
    uart_start : out std_logic;
    uart_dato : out std_logic_vector(7 downto 0);
    fin : out std_logic
  );
end entity;

architecture rtl of enviar_actitud_uart is
  type bytes_t is array (0 to 25) of std_logic_vector(7 downto 0);
  type estado_t is (REPOSO, PREPARAR, ENVIAR, ESPERAR);
  signal estado : estado_t := REPOSO;
  signal paquete : bytes_t;
  signal indice : natural range 0 to 26 := 0;
  signal suma : unsigned(7 downto 0) := (others => '0');
  signal dato : std_logic_vector(7 downto 0);
begin
  uart_dato <= dato;

  process(clk)
  begin
    if rising_edge(clk) then
      uart_start <= '0';
      fin <= '0';
      if reset = '1' then
        estado <= REPOSO;
        dato <= (others => '0');
      else
        case estado is
          when REPOSO =>
            if iniciar = '1' then
              paquete(0 to 3) <= (x"53", x"54", x"51", x"32");
              paquete(4) <= "0000000" & valido;
              paquete(5) <= "0000" & std_logic_vector(cantidad);
              for k in 0 to 3 loop
                paquete(6+k) <= std_logic_vector(foto(8*k+7 downto 8*k));
                for b in 0 to 3 loop
                  if valido = '1' then
                    paquete(10+4*k+b) <= std_logic_vector(q(k)(8*b+7 downto 8*b));
                  else
                    paquete(10+4*k+b) <= x"00";
                  end if;
                end loop;
              end loop;
              suma <= (others => '0');
              indice <= 0;
              estado <= PREPARAR;
            end if;
          when PREPARAR =>
            if indice = 26 then
              dato <= std_logic_vector(suma);
            else
              dato <= paquete(indice);
            end if;
            estado <= ENVIAR;
          when ENVIAR =>
            if uart_busy = '0' then
              uart_start <= '1';
              if indice < 26 then
                suma <= suma + unsigned(dato);
              end if;
              estado <= ESPERAR;
            end if;
          when ESPERAR =>
            if uart_done = '1' then
              if indice = 26 then
                fin <= '1';
                estado <= REPOSO;
              else
                indice <= indice + 1;
                estado <= PREPARAR;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
