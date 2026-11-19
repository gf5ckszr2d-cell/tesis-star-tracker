library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity enviar_centroides_uart is
    generic (UMBRAL : natural range 0 to 255 := 45);
    port (
        clk, reset, start, overflow : in std_logic;
        cantidad : in integer range 0 to 64;
        indice_estrella : out integer range 0 to 63;
        x_estrella, y_estrella, area_estrella : in unsigned(16 downto 0);
        intensidad_estrella : in unsigned(24 downto 0);
        uart_busy, uart_done : in std_logic;
        uart_start : out std_logic;
        uart_dato : out std_logic_vector(7 downto 0);
        fin : out std_logic
    );
end entity;

architecture rtl of enviar_centroides_uart is
    type estados is (REPOSO, PREPARAR_BYTE, ENVIAR_BYTE, ESPERAR_BYTE);
    type cabecera_t is array (0 to 3) of std_logic_vector(7 downto 0);
    constant CABECERA : cabecera_t := (x"53", x"54", x"43", x"31");
    signal estado : estados := REPOSO;
    signal posicion : integer range 0 to 1032 := 0;
    signal ultimo : integer range 8 to 1032 := 8;
    signal indice : integer range 0 to 63 := 0;
    signal byte_estrella : integer range 0 to 15 := 0;
    signal suma : unsigned(7 downto 0) := (others => '0');
    signal byte_siguiente : std_logic_vector(7 downto 0);
    signal byte_registro : std_logic_vector(7 downto 0) := (others => '0');
    signal estrella : std_logic_vector(127 downto 0);
begin
    indice_estrella <= indice;
    uart_dato <= byte_registro;
    estrella <= std_logic_vector(resize(intensidad_estrella, 32)) &
                std_logic_vector(resize(area_estrella, 32)) &
                std_logic_vector(resize(y_estrella, 32)) &
                std_logic_vector(resize(x_estrella, 32));

    process(posicion, cantidad, overflow, ultimo, suma, estrella, byte_estrella)
    begin
        if posicion < 4 then
            byte_siguiente <= CABECERA(posicion);
        elsif posicion = 4 then
            byte_siguiente <= std_logic_vector(to_unsigned(cantidad, 8));
        elsif posicion = 5 then
            byte_siguiente <= "0000000" & overflow;
        elsif posicion = 6 then
            byte_siguiente <= std_logic_vector(to_unsigned(UMBRAL, 8));
        elsif posicion = 7 then
            byte_siguiente <= x"00";
        elsif posicion = ultimo then
            byte_siguiente <= std_logic_vector(suma);
        else
            byte_siguiente <= estrella(8 * byte_estrella + 7 downto 8 * byte_estrella);
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            uart_start <= '0';
            fin <= '0';
            if reset = '1' then
                estado <= REPOSO;
                byte_registro <= (others => '0');
            else
                case estado is
                    when REPOSO =>
                        if start = '1' then
                            posicion <= 0;
                            ultimo <= 8 + 16 * cantidad;
                            indice <= 0;
                            byte_estrella <= 0;
                            suma <= (others => '0');
                            estado <= PREPARAR_BYTE;
                        end if;
                    when PREPARAR_BYTE =>
                        byte_registro <= byte_siguiente;
                        estado <= ENVIAR_BYTE;
                    when ENVIAR_BYTE =>
                        if uart_busy = '0' then
                            uart_start <= '1';
                            if posicion < ultimo then
                                suma <= suma + unsigned(byte_registro);
                            end if;
                            estado <= ESPERAR_BYTE;
                        end if;
                    when ESPERAR_BYTE =>
                        if uart_done = '1' then
                            if posicion = ultimo then
                                fin <= '1';
                                estado <= REPOSO;
                            else
                                posicion <= posicion + 1;
                                if posicion >= 8 then
                                    if byte_estrella = 15 then
                                        byte_estrella <= 0;
                                        if indice < 63 then
                                            indice <= indice + 1;
                                        end if;
                                    else
                                        byte_estrella <= byte_estrella + 1;
                                    end if;
                                end if;
                                estado <= PREPARAR_BYTE;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
