library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity enviar_matches_uart is
    port (
        clk, reset, nueva_foto, match_valido, iniciar : in std_logic;
        indice, id : in unsigned(7 downto 0);
        foto : in unsigned(31 downto 0);
        uart_busy, uart_done : in std_logic;
        uart_start : out std_logic;
        uart_dato : out std_logic_vector(7 downto 0);
        fin : out std_logic
    );
end entity;

architecture rtl of enviar_matches_uart is
    type estado_t is (REPOSO, PREPARAR, ENVIAR, ESPERAR);
    type bytes_t is array (0 to 24) of std_logic_vector(7 downto 0);
    signal estado : estado_t := REPOSO;
    signal datos : bytes_t := (others => x"FF");
    signal cantidad : natural range 0 to 8 := 0;
    signal posicion : natural range 0 to 25 := 0;
    signal suma : unsigned(7 downto 0) := (others => '0');
    signal dato : std_logic_vector(7 downto 0) := (others => '0');
begin
    uart_dato <= dato;
    process(clk)
    begin
        if rising_edge(clk) then
            uart_start <= '0';
            fin <= '0';
            if reset = '1' then
                estado <= REPOSO;
                cantidad <= 0;
                datos <= (others => x"FF");
            else
                case estado is
                    when REPOSO =>
                        if nueva_foto = '1' then
                            cantidad <= 0;
                            datos <= (others => x"FF");
                        elsif match_valido = '1' and cantidad < 8 then
                            datos(9+2*cantidad) <= std_logic_vector(indice);
                            datos(10+2*cantidad) <= std_logic_vector(id);
                            cantidad <= cantidad + 1;
                        end if;
                        if iniciar = '1' then
                            datos(0 to 3) <= (x"53", x"54", x"4D", x"31");
                            datos(4) <= std_logic_vector(to_unsigned(cantidad, 8));
                            for i in 0 to 3 loop
                                datos(5+i) <= std_logic_vector(foto(8*i+7 downto 8*i));
                            end loop;
                            posicion <= 0;
                            suma <= (others => '0');
                            estado <= PREPARAR;
                        end if;
                    when PREPARAR =>
                        if posicion = 25 then
                            dato <= std_logic_vector(suma);
                        else
                            dato <= datos(posicion);
                        end if;
                        estado <= ENVIAR;
                    when ENVIAR =>
                        if uart_busy = '0' then
                            uart_start <= '1';
                            suma <= suma + unsigned(dato);
                            estado <= ESPERAR;
                        end if;
                    when ESPERAR =>
                        if uart_done = '1' then
                            if posicion = 25 then
                                fin <= '1';
                                estado <= REPOSO;
                            else
                                posicion <= posicion + 1;
                                estado <= PREPARAR;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
