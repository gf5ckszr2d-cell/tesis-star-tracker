library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity umbral_posicion is
    port (
        clk, reset, start : in std_logic;
        dato_lectura, umbral : in std_logic_vector(7 downto 0);
        listo : in std_logic;
        direccion_lectura : out unsigned(16 downto 0);
        x, y : out unsigned(9 downto 0);
        luminancia : out std_logic_vector(7 downto 0);
        brillante, pixel_valido, ultimo_pixel, busy, done : out std_logic
    );
end entity;

architecture rtl of umbral_posicion is
    type estados is (REPOSO, PONER_DIRECCION, ESPERAR_DATO,
                     EVALUAR_PIXEL, ENTREGAR_PIXEL, AVANZAR_PIXEL, FIN);
    signal estado : estados := REPOSO;
    signal direccion : unsigned(16 downto 0) := (others => '0');
    signal columna, fila : unsigned(9 downto 0) := (others => '0');
begin
    direccion_lectura <= direccion;
    x <= columna;
    y <= fila;
    pixel_valido <= '1' when estado = ENTREGAR_PIXEL else '0';
    ultimo_pixel <= '1' when estado = ENTREGAR_PIXEL and direccion = 76799 else '0';
    busy <= '0' when estado = REPOSO else '1';
    done <= '1' when estado = FIN else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                estado <= REPOSO;
                direccion <= (others => '0');
                columna <= (others => '0');
                fila <= (others => '0');
                luminancia <= (others => '0');
                brillante <= '0';
            else
                case estado is
                    when REPOSO =>
                        if start = '1' then
                            direccion <= (others => '0');
                            columna <= (others => '0');
                            fila <= (others => '0');
                            estado <= PONER_DIRECCION;
                        end if;
                    when PONER_DIRECCION =>
                        estado <= ESPERAR_DATO;
                    when ESPERAR_DATO =>
                        estado <= EVALUAR_PIXEL;
                    when EVALUAR_PIXEL =>
                        luminancia <= dato_lectura;
                        if unsigned(dato_lectura) >= unsigned(umbral) then
                            brillante <= '1';
                        else
                            brillante <= '0';
                        end if;
                        estado <= ENTREGAR_PIXEL;
                    when ENTREGAR_PIXEL =>
                        if listo = '1' then
                            estado <= AVANZAR_PIXEL;
                        end if;
                    when AVANZAR_PIXEL =>
                        if direccion = 76799 then
                            estado <= FIN;
                        else
                            direccion <= direccion + 1;
                            if columna = 319 then
                                columna <= (others => '0');
                                fila <= fila + 1;
                            else
                                columna <= columna + 1;
                            end if;
                            estado <= PONER_DIRECCION;
                        end if;
                    when FIN =>
                        estado <= REPOSO;
                end case;
            end if;
        end if;
    end process;
end architecture;
