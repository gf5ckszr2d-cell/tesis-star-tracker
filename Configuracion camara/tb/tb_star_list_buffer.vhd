library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_star_list_buffer is
end entity;

architecture sim of tb_star_list_buffer is

    constant CLK_PERIOD : time := 10 ns;
    constant MAX_STARS : positive := 64;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal frame_start_toggle : std_logic := '0';
    signal frame_done : std_logic := '0';
    signal star_valid : std_logic := '0';
    signal centroid_x_q8_8 : unsigned(17 downto 0) := (others => '0');
    signal centroid_y_q8_8 : unsigned(17 downto 0) := (others => '0');
    signal star_area : unsigned(14 downto 0) := (others => '0');
    signal star_intensity : unsigned(23 downto 0) := (others => '0');
    signal rd_index : unsigned(7 downto 0) := (others => '0');
    signal rd_valid : std_logic;
    signal rd_centroid_x_q8_8 : unsigned(17 downto 0);
    signal rd_centroid_y_q8_8 : unsigned(17 downto 0);
    signal rd_star_area : unsigned(14 downto 0);
    signal rd_star_intensity : unsigned(23 downto 0);
    signal star_count : unsigned(7 downto 0);
    signal list_ready : std_logic;
    signal overflow : std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.star_list_buffer
        generic map (
            MAX_STARS => MAX_STARS
        )
        port map (
            clk => clk,
            rst => rst,
            frame_start_toggle => frame_start_toggle,
            frame_done => frame_done,
            star_valid => star_valid,
            centroid_x_q8_8 => centroid_x_q8_8,
            centroid_y_q8_8 => centroid_y_q8_8,
            star_area => star_area,
            star_intensity => star_intensity,
            rd_index => rd_index,
            rd_valid => rd_valid,
            rd_centroid_x_q8_8 => rd_centroid_x_q8_8,
            rd_centroid_y_q8_8 => rd_centroid_y_q8_8,
            rd_star_area => rd_star_area,
            rd_star_intensity => rd_star_intensity,
            star_count => star_count,
            list_ready => list_ready,
            overflow => overflow
        );

    stimulus : process

        procedure start_frame is
        begin
            frame_start_toggle <= not frame_start_toggle;
            wait until rising_edge(clk);
            wait for 1 ns;
            assert list_ready = '0' and star_count = 0 and overflow = '0'
                report "ERROR: el nuevo frame no limpio el estado logico"
                severity failure;
        end procedure;

        procedure push_star(
            constant x_value : natural;
            constant y_value : natural;
            constant area_value : natural;
            constant intensity_value : natural
        ) is
        begin
            centroid_x_q8_8 <= to_unsigned(x_value, centroid_x_q8_8'length);
            centroid_y_q8_8 <= to_unsigned(y_value, centroid_y_q8_8'length);
            star_area <= to_unsigned(area_value, star_area'length);
            star_intensity <= to_unsigned(intensity_value, star_intensity'length);
            star_valid <= '1';
            wait until rising_edge(clk);
            star_valid <= '0';
            wait until rising_edge(clk);
        end procedure;

        procedure finish_frame is
        begin
            frame_done <= '1';
            wait until rising_edge(clk);
            frame_done <= '0';
            wait until rising_edge(clk);
            wait for 1 ns;
            assert list_ready = '1'
                report "ERROR: list_ready no se activo"
                severity failure;
        end procedure;

        procedure check_entry(
            constant entry_index : natural;
            constant x_value : natural;
            constant y_value : natural;
            constant area_value : natural;
            constant intensity_value : natural
        ) is
        begin
            rd_index <= to_unsigned(entry_index, rd_index'length);
            wait until rising_edge(clk);
            wait for 1 ns;
            assert rd_valid = '1' and
                   rd_centroid_x_q8_8 = to_unsigned(x_value, rd_centroid_x_q8_8'length) and
                   rd_centroid_y_q8_8 = to_unsigned(y_value, rd_centroid_y_q8_8'length) and
                   rd_star_area = to_unsigned(area_value, rd_star_area'length) and
                   rd_star_intensity = to_unsigned(intensity_value, rd_star_intensity'length)
                report "ERROR: contenido incorrecto en entrada " & integer'image(entry_index)
                severity failure;
        end procedure;

    begin
        rst <= '1';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        -- Frame sin estrellas.
        start_frame;
        finish_frame;
        assert star_count = 0 and overflow = '0'
            report "ERROR: frame de cero estrellas incorrecto"
            severity failure;
        rd_index <= (others => '0');
        wait until rising_edge(clk);
        wait for 1 ns;
        assert rd_valid = '0'
            report "ERROR: existe una entrada valida en frame vacio"
            severity failure;

        -- Frame con una estrella.
        start_frame;
        push_star(320, 640, 3, 900);
        finish_frame;
        assert star_count = 1 and overflow = '0'
            report "ERROR: frame de una estrella incorrecto"
            severity failure;
        check_entry(0, 320, 640, 3, 900);
        rd_index <= to_unsigned(1, rd_index'length);
        wait until rising_edge(clk);
        wait for 1 ns;
        assert rd_valid = '0'
            report "ERROR: entrada fuera del conteo marcada valida"
            severity failure;

        -- Varias estrellas y lectura individual.
        start_frame;
        push_star(100, 200, 2, 300);
        push_star(400, 500, 6, 700);
        push_star(800, 900, 10, 1100);
        finish_frame;
        assert star_count = 3 and overflow = '0'
            report "ERROR: frame de varias estrellas incorrecto"
            severity failure;
        check_entry(0, 100, 200, 2, 300);
        check_entry(1, 400, 500, 6, 700);
        check_entry(2, 800, 900, 10, 1100);

        -- Nuevo frame: invalida logicamente la lista anterior y la reemplaza.
        start_frame;
        rd_index <= (others => '0');
        wait until rising_edge(clk);
        wait for 1 ns;
        assert rd_valid = '0'
            report "ERROR: quedaron datos validos del frame anterior"
            severity failure;
        push_star(1234, 2345, 12, 3456);
        finish_frame;
        assert star_count = 1
            report "ERROR: el nuevo frame no reemplazo el conteo anterior"
            severity failure;
        check_entry(0, 1234, 2345, 12, 3456);
        rd_index <= to_unsigned(1, rd_index'length);
        wait until rising_edge(clk);
        wait for 1 ns;
        assert rd_valid = '0'
            report "ERROR: la entrada antigua 1 sigue siendo valida"
            severity failure;

        -- Capacidad exacta de 64 entradas.
        start_frame;
        for index in 0 to MAX_STARS - 1 loop
            push_star(index * 16, index * 8, index + 1, 1000 + index);
        end loop;
        finish_frame;
        assert star_count = to_unsigned(MAX_STARS, star_count'length) and overflow = '0'
            report "ERROR: no se almacenaron exactamente 64 estrellas"
            severity failure;
        check_entry(0, 0, 0, 1, 1000);
        check_entry(MAX_STARS - 1, 1008, 504, 64, 1063);

        -- La entrada 65 activa overflow sin alterar las 64 entradas validas.
        start_frame;
        for index in 0 to MAX_STARS - 1 loop
            push_star(index * 16, index * 8, index + 1, 2000 + index);
        end loop;
        push_star(9999, 9999, 99, 9999);
        finish_frame;
        assert star_count = to_unsigned(MAX_STARS, star_count'length)
            report "ERROR: star_count excedio la capacidad"
            severity failure;
        assert overflow = '1'
            report "ERROR: no se activo overflow en la entrada 65"
            severity failure;
        check_entry(0, 0, 0, 1, 2000);
        check_entry(MAX_STARS - 1, 1008, 504, 64, 2063);

        report "PASS_STAR_LIST_BUFFER: cero, una, varias, reemplazo, capacidad 64 y overflow correctos";
        finish;
    end process;

    watchdog : process
    begin
        wait for 100 us;
        assert false
            report "ERROR: timeout tb_star_list_buffer"
            severity failure;
    end process;

end architecture;
