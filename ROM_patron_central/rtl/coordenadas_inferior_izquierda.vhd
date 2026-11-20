library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Adaptador combinacional. Entrada: indices de pixel desde arriba/izquierda.
-- Salida: X hacia la derecha, Y hacia arriba, escala 256 en ambos lados.
-- El origen es el centro del pixel inferior izquierdo, no el borde fisico.
entity coordenadas_inferior_izquierda is
    generic (
        ANCHO_IMAGEN : positive := 320;
        ALTO_IMAGEN : positive := 240
    );
    port (
        valido_entrada : in std_logic;
        x_c, y_c : in unsigned(16 downto 0);
        valido_salida : out std_logic;
        x, y : out unsigned(16 downto 0)
    );
end entity;

architecture rtl of coordenadas_inferior_izquierda is
    constant MAX_X : unsigned(16 downto 0) := to_unsigned((ANCHO_IMAGEN-1)*256,17);
    constant MAX_Y : unsigned(16 downto 0) := to_unsigned((ALTO_IMAGEN-1)*256,17);
begin
    assert ANCHO_IMAGEN <= 512 and ALTO_IMAGEN <= 512
        report "Las coordenadas de 17 bits con ocho fraccionarios no cubren esta imagen"
        severity failure;
    process(all)
    begin
        x <= (others => '0');
        y <= (others => '0');
        valido_salida <= '0';
        if valido_entrada = '1' then
            if x_c <= MAX_X and y_c <= MAX_Y then
                x <= x_c;
                y <= MAX_Y-y_c;
                valido_salida <= '1';
            end if;
        end if;
    end process;
end architecture;
