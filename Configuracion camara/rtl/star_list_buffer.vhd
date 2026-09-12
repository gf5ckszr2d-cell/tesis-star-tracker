library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity star_list_buffer is
    generic (
        MAX_STARS : positive := 64
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        frame_start_toggle : in std_logic;
        frame_done         : in std_logic;

        star_valid      : in std_logic;
        centroid_x_q8_8 : in unsigned(17 downto 0);
        centroid_y_q8_8 : in unsigned(17 downto 0);
        star_area       : in unsigned(14 downto 0);
        star_intensity  : in unsigned(23 downto 0);

        rd_index      : in unsigned(7 downto 0);
        rd_valid      : out std_logic;
        rd_centroid_x_q8_8 : out unsigned(17 downto 0);
        rd_centroid_y_q8_8 : out unsigned(17 downto 0);
        rd_star_area      : out unsigned(14 downto 0);
        rd_star_intensity : out unsigned(23 downto 0);

        star_count : out unsigned(7 downto 0);
        list_ready : out std_logic;
        overflow   : out std_logic
    );
end entity;

architecture rtl of star_list_buffer is

    constant ENTRY_WIDTH : positive := 75;
    type star_memory_t is array (0 to MAX_STARS - 1) of
        std_logic_vector(ENTRY_WIDTH - 1 downto 0);

    -- Memoria RTL sin atributo de tecnologia: Vivado decide su implementacion.
    signal star_memory : star_memory_t;

    signal frame_start_toggle_prev : std_logic := '0';
    signal write_count : integer range 0 to MAX_STARS := 0;
    signal star_count_reg : unsigned(7 downto 0) := (others => '0');
    signal list_ready_reg : std_logic := '0';
    signal overflow_reg : std_logic := '0';
    signal rd_valid_reg : std_logic := '0';
    signal rd_centroid_x_reg : unsigned(17 downto 0) := (others => '0');
    signal rd_centroid_y_reg : unsigned(17 downto 0) := (others => '0');
    signal rd_star_area_reg : unsigned(14 downto 0) := (others => '0');
    signal rd_star_intensity_reg : unsigned(23 downto 0) := (others => '0');

begin

    assert MAX_STARS <= 255
        report "star_list_buffer requiere MAX_STARS <= 255"
        severity failure;

    star_count <= star_count_reg;
    list_ready <= list_ready_reg;
    overflow <= overflow_reg;
    rd_valid <= rd_valid_reg and list_ready_reg;
    rd_centroid_x_q8_8 <= rd_centroid_x_reg;
    rd_centroid_y_q8_8 <= rd_centroid_y_reg;
    rd_star_area <= rd_star_area_reg;
    rd_star_intensity <= rd_star_intensity_reg;

    -- Puerto de lectura sincrono. Esta forma no fija la tecnologia fisica y
    -- permite que sintesis elija registros, LUTRAM o BRAM segun convenga.
    process(clk)
        variable read_position : integer;
    begin
        if rising_edge(clk) then
            rd_valid_reg <= '0';
            rd_centroid_x_reg <= (others => '0');
            rd_centroid_y_reg <= (others => '0');
            rd_star_area_reg <= (others => '0');
            rd_star_intensity_reg <= (others => '0');

            read_position := to_integer(rd_index);
            if list_ready_reg = '1' and
               read_position < to_integer(star_count_reg) and
               read_position < MAX_STARS then
                rd_valid_reg <= '1';
                rd_centroid_x_reg <= unsigned(star_memory(read_position)(74 downto 57));
                rd_centroid_y_reg <= unsigned(star_memory(read_position)(56 downto 39));
                rd_star_area_reg <= unsigned(star_memory(read_position)(38 downto 24));
                rd_star_intensity_reg <= unsigned(star_memory(read_position)(23 downto 0));
            end if;
        end if;
    end process;

    process(clk)
        variable final_count : integer range 0 to MAX_STARS;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                frame_start_toggle_prev <= frame_start_toggle;
                write_count <= 0;
                star_count_reg <= (others => '0');
                list_ready_reg <= '0';
                overflow_reg <= '0';
            elsif frame_start_toggle /= frame_start_toggle_prev then
                frame_start_toggle_prev <= frame_start_toggle;
                write_count <= 0;
                star_count_reg <= (others => '0');
                list_ready_reg <= '0';
                overflow_reg <= '0';
            else
                final_count := write_count;

                if star_valid = '1' then
                    if write_count < MAX_STARS then
                        star_memory(write_count) <=
                            std_logic_vector(centroid_x_q8_8) &
                            std_logic_vector(centroid_y_q8_8) &
                            std_logic_vector(star_area) &
                            std_logic_vector(star_intensity);
                        write_count <= write_count + 1;
                        final_count := write_count + 1;
                    else
                        overflow_reg <= '1';
                    end if;
                end if;

                if frame_done = '1' then
                    star_count_reg <= to_unsigned(final_count, star_count_reg'length);
                    list_ready_reg <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture;
