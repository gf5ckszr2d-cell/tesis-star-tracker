library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_capture_storage_integration_top is
end entity;

architecture sim of tb_capture_storage_integration_top is
    constant FRAME_WIDTH : integer := 160;
    constant FRAME_HEIGHT : integer := 120;
    constant FRAME_PIXELS : integer := FRAME_WIDTH * FRAME_HEIGHT;
    constant ADDR_WIDTH : integer := 15;
    constant PCLK_PERIOD : time := 40 ns;
    constant RD_CLK_PERIOD : time := 10 ns;

    signal pclk, rd_clk : std_logic := '0';
    signal rst, enable, arm_capture, dump_done_toggle : std_logic := '0';
    signal cam_vsync : std_logic := '1';
    signal cam_href : std_logic := '0';
    signal cam_data : std_logic_vector(7 downto 0) := (others => '0');
    signal rd_addr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_data, pixel_y, wr_data : std_logic_vector(7 downto 0);
    signal pixel_valid, frame_active, frame_done, wr_en : std_logic;
    signal pixel_x, pixel_y_pos : unsigned(9 downto 0);
    signal wr_addr : unsigned(ADDR_WIDTH - 1 downto 0);
    signal capture_busy, frame_ready, frame_ready_toggle : std_logic;
    signal capture_overflow, store_overflow : std_logic;
    signal pixel_count : integer range 0 to FRAME_PIXELS := 0;
    signal write_count : integer range 0 to FRAME_PIXELS := 0;
    signal frame_done_count : integer range 0 to 2 := 0;

    function expected_y(index : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned((index * 5 + 17) mod 256, 8));
    end function;
begin
    uut : entity work.capture_storage_integration_top
        generic map (
            FRAME_WIDTH => FRAME_WIDTH,
            FRAME_HEIGHT => FRAME_HEIGHT,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            pclk => pclk, rst => rst, enable => enable,
            arm_capture => arm_capture, dump_done_toggle => dump_done_toggle,
            cam_vsync => cam_vsync, cam_href => cam_href, cam_data => cam_data,
            rd_clk => rd_clk, rd_addr => rd_addr, rd_data => rd_data,
            pixel_y => pixel_y, pixel_valid => pixel_valid,
            pixel_x => pixel_x, pixel_y_pos => pixel_y_pos,
            frame_active => frame_active, frame_done => frame_done,
            wr_en => wr_en, wr_addr => wr_addr, wr_data => wr_data,
            capture_busy => capture_busy, frame_ready => frame_ready,
            frame_ready_toggle => frame_ready_toggle,
            capture_overflow => capture_overflow,
            store_overflow => store_overflow
        );

    pclk <= not pclk after PCLK_PERIOD / 2;
    rd_clk <= not rd_clk after RD_CLK_PERIOD / 2;

    stimulus : process
        procedure send_camera_byte(value : std_logic_vector(7 downto 0)) is
        begin
            cam_data <= value;
            wait until rising_edge(pclk);
        end procedure;

        procedure send_line(row : integer) is
            variable first_index, second_index : integer;
        begin
            cam_href <= '1';
            for pair_index in 0 to (FRAME_WIDTH / 2) - 1 loop
                first_index := row * FRAME_WIDTH + pair_index * 2;
                second_index := first_index + 1;
                send_camera_byte(expected_y(first_index));
                send_camera_byte(x"A5");
                send_camera_byte(expected_y(second_index));
                send_camera_byte(x"5A");
            end loop;
            cam_href <= '0';
            cam_data <= (others => '0');
            wait until rising_edge(pclk);
            wait until rising_edge(pclk);
        end procedure;
    begin
        report "============================================================";
        report "TEST INTEGRADO 2: CAPTURA Y ALMACENAMIENTO";
        report "capture_y_stream + frame_capture_store + framebuffer_y_bram";
        report "============================================================";

        rst <= '1';
        wait for 8 * PCLK_PERIOD;
        rst <= '0';

        report "[FASE 1/4] Activando captura en mitad de un frame invalido";
        enable <= '1';
        arm_capture <= '1';
        cam_vsync <= '0';
        cam_href <= '1';
        for index in 0 to 15 loop
            send_camera_byte(std_logic_vector(to_unsigned(16#D0# + index, 8)));
        end loop;
        arm_capture <= '0';
        cam_href <= '0';
        wait until rising_edge(pclk);
        assert pixel_count = 0 and write_count = 0
            report "ERROR: se capturo antes de sincronizar con VSYNC" severity failure;
        report "[OK 1/4] Datos de mitad de frame ignorados";

        report "[FASE 2/4] Enviando frame YUYV QQVGA completo";
        cam_vsync <= '1';
        wait until rising_edge(pclk);
        wait until rising_edge(pclk);
        cam_vsync <= '0';
        wait until rising_edge(pclk);

        for row in 0 to FRAME_HEIGHT - 1 loop
            send_line(row);
        end loop;

        cam_vsync <= '1';
        wait until rising_edge(pclk);
        wait until frame_ready = '1' for 50 us;
        wait until rising_edge(pclk);

        assert frame_ready = '1' report "ERROR: frame_ready no se activo" severity failure;
        assert pixel_count = FRAME_PIXELS
            report "ERROR: cantidad de pixeles Y distinta de 19200" severity failure;
        assert write_count = FRAME_PIXELS
            report "ERROR: cantidad de escrituras BRAM distinta de 19200" severity failure;
        assert frame_done_count = 1
            report "ERROR: frame_done no fue un pulso unico" severity failure;
        assert capture_overflow = '0' and store_overflow = '0'
            report "ERROR: overflow durante frame valido" severity failure;
        report "[OK 2/4] 19200 pixeles Y escritos en orden espacial";

        report "[FASE 3/4] Leyendo y comparando las 19200 posiciones BRAM";
        for index in 0 to FRAME_PIXELS - 1 loop
            rd_addr <= to_unsigned(index, ADDR_WIDTH);
            wait until rising_edge(rd_clk);
            wait for 1 ns;
            assert rd_data = expected_y(index)
                report "ERROR: contenido BRAM incorrecto en direccion " &
                       integer'image(index) severity failure;
        end loop;
        report "[OK 3/4] Contenido completo de BRAM verificado";

        report "[FASE 4/4] Liberando el frame despues del consumo";
        dump_done_toggle <= not dump_done_toggle;
        wait until rising_edge(pclk);
        wait until rising_edge(pclk);
        wait for 1 ns;
        assert frame_ready = '0'
            report "ERROR: frame_ready no se limpio con dump_done_toggle" severity failure;
        report "[OK 4/4] Handshake de liberacion verificado";

        report "============================================================";
        report "PASS_CAPTURE_STORAGE_INTEGRATION: TODAS LAS PRUEBAS PASARON";
        report "============================================================";
        finish;
    end process;

    pixel_monitor : process
        variable expected_index : integer;
    begin
        wait until rst = '0';
        while true loop
            wait until rising_edge(pclk);
            wait for 1 ns;
            if pixel_valid = '1' then
                expected_index := pixel_count;
                assert pixel_y = expected_y(expected_index)
                    report "ERROR: luminancia Y incorrecta" severity failure;
                assert pixel_x = to_unsigned(expected_index mod FRAME_WIDTH, pixel_x'length)
                    report "ERROR: coordenada X incorrecta" severity failure;
                assert pixel_y_pos = to_unsigned(expected_index / FRAME_WIDTH, pixel_y_pos'length)
                    report "ERROR: coordenada Y incorrecta" severity failure;
                pixel_count <= pixel_count + 1;
            end if;
            if frame_done = '1' then
                frame_done_count <= frame_done_count + 1;
            end if;
        end loop;
    end process;

    write_monitor : process
        variable expected_index : integer;
    begin
        wait until rst = '0';
        while true loop
            wait until rising_edge(pclk);
            wait for 1 ns;
            if wr_en = '1' then
                expected_index := write_count;
                assert wr_addr = to_unsigned(expected_index, ADDR_WIDTH)
                    report "ERROR: direccion de escritura BRAM fuera de orden" severity failure;
                assert wr_data = expected_y(expected_index)
                    report "ERROR: dato de escritura BRAM incorrecto" severity failure;
                write_count <= write_count + 1;
            end if;
        end loop;
    end process;

    watchdog : process
    begin
        wait for 10 ms;
        assert false report "ERROR: timeout captura y almacenamiento" severity failure;
    end process;
end architecture;
