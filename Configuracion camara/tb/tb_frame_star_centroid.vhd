library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_frame_star_centroid is
end entity;

architecture sim of tb_frame_star_centroid is

    constant CLK_PERIOD : time := 10 ns;
    constant FRAME_WIDTH : positive := 8;
    constant FRAME_HEIGHT : positive := 6;
    constant FRAME_PIXELS : positive := FRAME_WIDTH * FRAME_HEIGHT;
    constant ADDR_WIDTH : positive := 6;

    type frame_t is array (0 to FRAME_PIXELS - 1) of std_logic_vector(7 downto 0);

    function make_frame return frame_t is
        variable result : frame_t := (others => x"0A");
    begin
        -- Estrella 0: centroide ponderado (1.666, 1.500), area 4.
        result(1 * FRAME_WIDTH + 1) := x"78";
        result(1 * FRAME_WIDTH + 2) := x"F0";
        result(2 * FRAME_WIDTH + 1) := x"78";
        result(2 * FRAME_WIDTH + 2) := x"F0";

        -- Estrella 1: centroide ponderado (5.000, 3.500), area 2.
        result(3 * FRAME_WIDTH + 5) := x"C8";
        result(4 * FRAME_WIDTH + 5) := x"C8";
        return result;
    end function;

    constant FRAME_DATA : frame_t := make_frame;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal frame_ready_toggle : std_logic := '0';
    signal rd_addr : unsigned(ADDR_WIDTH - 1 downto 0);
    signal rd_data : std_logic_vector(7 downto 0) := (others => '0');
    signal star_valid : std_logic;
    signal star_index : unsigned(7 downto 0);
    signal centroid_x_q8_8 : unsigned(17 downto 0);
    signal centroid_y_q8_8 : unsigned(17 downto 0);
    signal star_area : unsigned(14 downto 0);
    signal star_intensity : unsigned(23 downto 0);
    signal star_count : unsigned(7 downto 0);
    signal process_busy : std_logic;
    signal process_done : std_logic;
    signal process_done_toggle : std_logic;
    signal overflow : std_logic;
    signal observed_stars : integer range 0 to 2 := 0;
    signal list_rd_index : unsigned(7 downto 0) := (others => '0');
    signal list_rd_valid : std_logic;
    signal list_rd_centroid_x_q8_8 : unsigned(17 downto 0);
    signal list_rd_centroid_y_q8_8 : unsigned(17 downto 0);
    signal list_rd_star_area : unsigned(14 downto 0);
    signal list_rd_star_intensity : unsigned(23 downto 0);
    signal stored_star_count : unsigned(7 downto 0);
    signal list_ready : std_logic;
    signal list_overflow : std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.frame_star_centroid
        generic map (
            FRAME_WIDTH => FRAME_WIDTH,
            FRAME_HEIGHT => FRAME_HEIGHT,
            ADDR_WIDTH => ADDR_WIDTH,
            MAX_LABELS => 8,
            MIN_AREA => 2,
            MAX_AREA => 12
        )
        port map (
            clk => clk,
            rst => rst,
            frame_ready_toggle => frame_ready_toggle,
            threshold => x"64",
            rd_addr => rd_addr,
            rd_data => rd_data,
            star_valid => star_valid,
            star_index => star_index,
            centroid_x_q8_8 => centroid_x_q8_8,
            centroid_y_q8_8 => centroid_y_q8_8,
            star_area => star_area,
            star_intensity => star_intensity,
            star_count => star_count,
            process_busy => process_busy,
            process_done => process_done,
            process_done_toggle => process_done_toggle,
            overflow => overflow
        );

    u_star_list_buffer : entity work.star_list_buffer
        generic map (
            MAX_STARS => 8
        )
        port map (
            clk => clk,
            rst => rst,
            frame_start_toggle => frame_ready_toggle,
            frame_done => process_done,
            star_valid => star_valid,
            centroid_x_q8_8 => centroid_x_q8_8,
            centroid_y_q8_8 => centroid_y_q8_8,
            star_area => star_area,
            star_intensity => star_intensity,
            rd_index => list_rd_index,
            rd_valid => list_rd_valid,
            rd_centroid_x_q8_8 => list_rd_centroid_x_q8_8,
            rd_centroid_y_q8_8 => list_rd_centroid_y_q8_8,
            rd_star_area => list_rd_star_area,
            rd_star_intensity => list_rd_star_intensity,
            star_count => stored_star_count,
            list_ready => list_ready,
            overflow => list_overflow
        );

    bram_read_model : process(clk)
    begin
        if rising_edge(clk) then
            if to_integer(rd_addr) < FRAME_PIXELS then
                rd_data <= FRAME_DATA(to_integer(rd_addr));
            else
                rd_data <= (others => '0');
            end if;
        end if;
    end process;

    result_monitor : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                observed_stars <= 0;
            elsif star_valid = '1' then
                if observed_stars = 0 then
                    assert star_index = to_unsigned(0, star_index'length)
                        report "ERROR: indice de primera estrella incorrecto"
                        severity failure;
                    assert centroid_x_q8_8 = to_unsigned(426, centroid_x_q8_8'length)
                        report "ERROR: centroide X de primera estrella incorrecto"
                        severity failure;
                    assert centroid_y_q8_8 = to_unsigned(384, centroid_y_q8_8'length)
                        report "ERROR: centroide Y de primera estrella incorrecto"
                        severity failure;
                    assert star_area = to_unsigned(4, star_area'length)
                        report "ERROR: area de primera estrella incorrecta"
                        severity failure;
                    assert star_intensity = to_unsigned(720, star_intensity'length)
                        report "ERROR: intensidad de primera estrella incorrecta"
                        severity failure;
                elsif observed_stars = 1 then
                    assert star_index = to_unsigned(1, star_index'length)
                        report "ERROR: indice de segunda estrella incorrecto"
                        severity failure;
                    assert centroid_x_q8_8 = to_unsigned(1280, centroid_x_q8_8'length)
                        report "ERROR: centroide X de segunda estrella incorrecto"
                        severity failure;
                    assert centroid_y_q8_8 = to_unsigned(896, centroid_y_q8_8'length)
                        report "ERROR: centroide Y de segunda estrella incorrecto"
                        severity failure;
                    assert star_area = to_unsigned(2, star_area'length)
                        report "ERROR: area de segunda estrella incorrecta"
                        severity failure;
                    assert star_intensity = to_unsigned(400, star_intensity'length)
                        report "ERROR: intensidad de segunda estrella incorrecta"
                        severity failure;
                end if;
                observed_stars <= observed_stars + 1;
            end if;
        end if;
    end process;

    stimulus : process
        variable initial_done_toggle : std_logic;
    begin
        rst <= '1';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        initial_done_toggle := process_done_toggle;
        frame_ready_toggle <= not frame_ready_toggle;

        wait until process_busy = '1' for 10 us;
        assert process_busy = '1'
            report "ERROR: detector no inicio al recibir frame_ready_toggle"
            severity failure;

        wait until process_done = '1' for 100 us;
        assert process_done = '1'
            report "ERROR: detector no termino"
            severity failure;
        assert overflow = '0'
            report "ERROR: detector marco overflow"
            severity failure;
        assert observed_stars = 2
            report "ERROR: cantidad de pulsos star_valid incorrecta"
            severity failure;
        assert star_count = to_unsigned(2, star_count'length)
            report "ERROR: star_count incorrecto"
            severity failure;
        assert process_done_toggle /= initial_done_toggle
            report "ERROR: process_done_toggle no cambio"
            severity failure;

        wait until list_ready = '1' for 1 us;
        assert list_ready = '1'
            report "ERROR: la lista de estrellas no quedo lista"
            severity failure;
        assert list_overflow = '0'
            report "ERROR: la lista de estrellas marco overflow"
            severity failure;
        assert stored_star_count = to_unsigned(2, stored_star_count'length)
            report "ERROR: star_count almacenado incorrecto"
            severity failure;

        list_rd_index <= to_unsigned(0, list_rd_index'length);
        wait until rising_edge(clk);
        wait for 1 ns;
        assert list_rd_valid = '1' and
               list_rd_centroid_x_q8_8 = to_unsigned(426, list_rd_centroid_x_q8_8'length) and
               list_rd_centroid_y_q8_8 = to_unsigned(384, list_rd_centroid_y_q8_8'length) and
               list_rd_star_area = to_unsigned(4, list_rd_star_area'length) and
               list_rd_star_intensity = to_unsigned(720, list_rd_star_intensity'length)
            report "ERROR: registro 0 de la lista incorrecto"
            severity failure;

        list_rd_index <= to_unsigned(1, list_rd_index'length);
        wait until rising_edge(clk);
        wait for 1 ns;
        assert list_rd_valid = '1' and
               list_rd_centroid_x_q8_8 = to_unsigned(1280, list_rd_centroid_x_q8_8'length) and
               list_rd_centroid_y_q8_8 = to_unsigned(896, list_rd_centroid_y_q8_8'length) and
               list_rd_star_area = to_unsigned(2, list_rd_star_area'length) and
               list_rd_star_intensity = to_unsigned(400, list_rd_star_intensity'length)
            report "ERROR: registro 1 de la lista incorrecto"
            severity failure;

        report "PASS_FRAME_STAR_CENTROID: deteccion, centroides Q8.8 y lista persistente correctos";
        finish;
    end process;

    watchdog : process
    begin
        wait for 200 us;
        assert false
            report "ERROR: timeout tb_frame_star_centroid"
            severity failure;
    end process;

end architecture;
