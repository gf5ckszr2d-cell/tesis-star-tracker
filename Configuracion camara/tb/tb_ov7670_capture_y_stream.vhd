library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_ov7670_capture_y_stream is
end entity;

architecture sim of tb_ov7670_capture_y_stream is

    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

    constant PCLK_PERIOD : time := 40 ns;
    constant TEST_WIDTH  : integer := 4;
    constant TEST_HEIGHT : integer := 2;

    constant LINE0_BYTES : byte_array_t := (
        x"10", x"A0", x"11", x"B0",
        x"12", x"A1", x"13", x"B1"
    );

    constant LINE1_BYTES : byte_array_t := (
        x"20", x"A2", x"21", x"B2",
        x"22", x"A3", x"23", x"B3"
    );

    constant EXPECTED_Y : byte_array_t := (
        x"10", x"11", x"12", x"13",
        x"20", x"21", x"22", x"23"
    );

    signal pclk   : std_logic := '0';
    signal rst    : std_logic := '1';
    signal enable : std_logic := '0';

    signal vsync : std_logic := '1';
    signal href  : std_logic := '0';
    signal data  : std_logic_vector(7 downto 0) := (others => '0');

    signal pixel_y      : std_logic_vector(7 downto 0);
    signal pixel_valid  : std_logic;
    signal pixel_x      : unsigned(9 downto 0);
    signal pixel_y_pos  : unsigned(9 downto 0);
    signal frame_active : std_logic;
    signal frame_done   : std_logic;
    signal overflow     : std_logic;

    signal seen_pixel_count : integer range 0 to EXPECTED_Y'length := 0;

begin

    uut : entity work.ov7670_capture_y_stream
        generic map (
            FRAME_WIDTH        => TEST_WIDTH,
            FRAME_HEIGHT       => TEST_HEIGHT,
            VSYNC_ACTIVE_LEVEL => '1',
            HREF_ACTIVE_LEVEL  => '1'
        )
        port map (
            pclk         => pclk,
            rst          => rst,
            enable       => enable,
            vsync        => vsync,
            href         => href,
            data         => data,
            pixel_y      => pixel_y,
            pixel_valid  => pixel_valid,
            pixel_x      => pixel_x,
            pixel_y_pos  => pixel_y_pos,
            frame_active => frame_active,
            frame_done   => frame_done,
            overflow     => overflow
        );

    pclk_process : process
    begin
        while true loop
            pclk <= '0';
            wait for PCLK_PERIOD / 2;
            pclk <= '1';
            wait for PCLK_PERIOD / 2;
        end loop;
    end process;

    stimulus : process

        procedure send_line(constant line_bytes : in byte_array_t) is
        begin
            href <= '1';
            for index in line_bytes'range loop
                data <= line_bytes(index);
                wait until rising_edge(pclk);
            end loop;
            href <= '0';
            data <= (others => '0');
            wait until rising_edge(pclk);
            wait until rising_edge(pclk);
        end procedure;

    begin
        report "Inicio test unitario ov7670_capture_y_stream";

        rst <= '1';
        enable <= '0';
        vsync <= '1';
        href <= '0';
        data <= (others => '0');

        wait for 5 * PCLK_PERIOD;

        rst <= '0';
        vsync <= '0';
        href <= '1';
        data <= x"EE";
        enable <= '1';

        for index in 0 to 5 loop
            wait until rising_edge(pclk);
            data <= std_logic_vector(to_unsigned(16#E0# + index, data'length));
        end loop;

        wait for 1 ns;

        assert seen_pixel_count = 0
            report "ERROR: la FSM capturo pixeles antes de sincronizar con VSYNC"
            severity failure;

        assert frame_active = '0'
            report "ERROR: frame_active se activo antes de una sincronizacion valida"
            severity failure;

        href <= '0';
        data <= (others => '0');
        wait until rising_edge(pclk);

        vsync <= '1';
        wait until rising_edge(pclk);
        wait until rising_edge(pclk);

        vsync <= '0';
        wait until rising_edge(pclk);

        send_line(LINE0_BYTES);
        send_line(LINE1_BYTES);

        vsync <= '1';
        wait until rising_edge(pclk);
        wait for 1 ns;

        assert frame_done = '1'
            report "ERROR: frame_done no se activo al final del frame"
            severity failure;

        assert seen_pixel_count = EXPECTED_Y'length
            report "ERROR: no se capturaron todos los pixeles Y esperados"
            severity failure;

        assert overflow = '0'
            report "ERROR: overflow activo en frame valido"
            severity failure;

        wait for 5 * PCLK_PERIOD;

        report "PASS_OV7670_CAPTURE_Y_STREAM: frame YUV422 capturado correctamente";

        finish;
    end process;

    monitor : process(pclk)
    begin
        if rising_edge(pclk) then
            if rst = '1' then
                seen_pixel_count <= 0;
            elsif pixel_valid = '1' then
                assert seen_pixel_count < EXPECTED_Y'length
                    report "ERROR: se emitieron mas pixeles Y de los esperados"
                    severity failure;

                assert pixel_y = EXPECTED_Y(seen_pixel_count)
                    report "ERROR: pixel_y no coincide"
                    severity failure;

                assert pixel_x = to_unsigned(seen_pixel_count mod TEST_WIDTH, pixel_x'length)
                    report "ERROR: pixel_x no coincide"
                    severity failure;

                assert pixel_y_pos = to_unsigned(seen_pixel_count / TEST_WIDTH, pixel_y_pos'length)
                    report "ERROR: pixel_y_pos no coincide"
                    severity failure;

                seen_pixel_count <= seen_pixel_count + 1;

                if seen_pixel_count = EXPECTED_Y'length - 1 then
                    report "Todos los pixeles Y esperados fueron capturados por la FSM";
                end if;
            end if;
        end if;
    end process;

    watchdog : process
    begin
        wait for 20 us;
        assert false
            report "ERROR: timeout test unitario ov7670_capture_y_stream"
            severity failure;
    end process;

end architecture;
