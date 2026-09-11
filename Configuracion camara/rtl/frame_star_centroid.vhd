library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_star_centroid is
    generic (
        FRAME_WIDTH  : positive := 160;
        FRAME_HEIGHT : positive := 120;
        ADDR_WIDTH   : positive := 15;
        MAX_LABELS   : positive := 64;
        MIN_AREA     : positive := 2;
        MAX_AREA     : positive := 500
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        frame_ready_toggle : in std_logic;
        threshold          : in std_logic_vector(7 downto 0);

        rd_addr : out unsigned(ADDR_WIDTH - 1 downto 0);
        rd_data : in std_logic_vector(7 downto 0);

        star_valid       : out std_logic;
        star_index       : out unsigned(7 downto 0);
        centroid_x_q8_8  : out unsigned(17 downto 0);
        centroid_y_q8_8  : out unsigned(17 downto 0);
        star_area        : out unsigned(14 downto 0);
        star_intensity   : out unsigned(23 downto 0);
        star_count       : out unsigned(7 downto 0);

        process_busy        : out std_logic;
        process_done        : out std_logic;
        process_done_toggle : out std_logic;
        overflow            : out std_logic
    );
end entity;

architecture rtl of frame_star_centroid is

    constant FRAME_PIXELS : positive := FRAME_WIDTH * FRAME_HEIGHT;
    constant DIV_NUM_WIDTH : positive := 40;
    constant DIV_DEN_WIDTH : positive := 24;

    subtype label_t is integer range 0 to MAX_LABELS;

    type state_t is (
        IDLE,
        SET_PIXEL_ADDRESS,
        WAIT_PIXEL_DATA,
        EVALUATE_PIXEL,
        RESOLVE_NEIGHBOR,
        WALK_PARENT,
        SELECT_TARGET,
        SELECT_TARGET_STEP,
        PREPARE_TARGET,
        MERGE_ROOTS,
        APPLY_MERGE,
        ACCUMULATE_PIXEL,
        DROP_PIXEL,
        ADVANCE_PIXEL,
        SCAN_RESULTS,
        WAIT_DIVIDE_X,
        WAIT_DIVIDE_Y,
        EMIT_STAR,
        DONE_STATE
    );

    type line_labels_t is array (0 to FRAME_WIDTH - 1) of label_t;
    type label_vector_t is array (0 to 3) of label_t;
    type parent_table_t is array (0 to MAX_LABELS) of label_t;
    type area_table_t is array (0 to MAX_LABELS) of unsigned(14 downto 0);
    type sum_i_table_t is array (0 to MAX_LABELS) of unsigned(23 downto 0);
    type sum_xy_table_t is array (0 to MAX_LABELS) of unsigned(31 downto 0);

    signal state : state_t := IDLE;
    signal ready_toggle_prev : std_logic := '0';

    signal line_a : line_labels_t := (others => 0);
    signal line_b : line_labels_t := (others => 0);
    signal parent_table : parent_table_t := (others => 0);
    signal area_table : area_table_t := (others => (others => '0'));
    signal sum_i_table : sum_i_table_t := (others => (others => '0'));
    signal sum_xi_table : sum_xy_table_t := (others => (others => '0'));
    signal sum_yi_table : sum_xy_table_t := (others => (others => '0'));

    signal neighbors : label_vector_t := (others => 0);
    signal roots : label_vector_t := (others => 0);
    signal neighbor_index : integer range 0 to 3 := 0;
    signal merge_index : integer range 0 to 3 := 0;
    signal merge_root_label : label_t := 0;
    signal walk_label : label_t := 0;
    signal walk_steps : integer range 0 to MAX_LABELS := 0;
    signal target_label : label_t := 0;

    signal scan_x : integer range 0 to FRAME_WIDTH - 1 := 0;
    signal scan_y : integer range 0 to FRAME_HEIGHT - 1 := 0;
    signal next_label : integer range 1 to MAX_LABELS + 1 := 1;
    signal result_label : integer range 1 to MAX_LABELS + 1 := 1;
    signal centroid_label : label_t := 0;
    signal pixel_reg : unsigned(7 downto 0) := (others => '0');

    signal rd_addr_reg : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal star_valid_reg : std_logic := '0';
    signal star_index_reg : unsigned(7 downto 0) := (others => '0');
    signal centroid_x_reg : unsigned(17 downto 0) := (others => '0');
    signal centroid_y_reg : unsigned(17 downto 0) := (others => '0');
    signal star_area_reg : unsigned(14 downto 0) := (others => '0');
    signal star_intensity_reg : unsigned(23 downto 0) := (others => '0');
    signal star_count_reg : unsigned(7 downto 0) := (others => '0');

    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';
    signal done_toggle_reg : std_logic := '0';
    signal overflow_reg : std_logic := '0';

    signal divider_start : std_logic := '0';
    signal divider_numerator : unsigned(DIV_NUM_WIDTH - 1 downto 0) := (others => '0');
    signal divider_denominator : unsigned(DIV_DEN_WIDTH - 1 downto 0) := (others => '0');
    signal divider_quotient : unsigned(17 downto 0);
    signal divider_busy : std_logic;
    signal divider_done : std_logic;

    -- Estas dos fronteras registradas separan la búsqueda de raíces de las
    -- escrituras en las memorias de acumuladores. KEEP evita que síntesis
    -- vuelva a plegarlas en una ruta combinacional de un solo ciclo.
    attribute KEEP : string;
    attribute KEEP of target_label : signal is "TRUE";
    attribute KEEP of merge_root_label : signal is "TRUE";
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of target_label : signal is "TRUE";
    attribute DONT_TOUCH of merge_root_label : signal is "TRUE";

begin

    assert MAX_LABELS <= 255
        report "frame_star_centroid requiere MAX_LABELS <= 255"
        severity failure;

    assert MIN_AREA <= MAX_AREA
        report "frame_star_centroid requiere MIN_AREA <= MAX_AREA"
        severity failure;

    rd_addr <= rd_addr_reg;
    star_valid <= star_valid_reg;
    star_index <= star_index_reg;
    centroid_x_q8_8 <= centroid_x_reg;
    centroid_y_q8_8 <= centroid_y_reg;
    star_area <= star_area_reg;
    star_intensity <= star_intensity_reg;
    star_count <= star_count_reg;
    process_busy <= busy_reg;
    process_done <= done_reg;
    process_done_toggle <= done_toggle_reg;
    overflow <= overflow_reg;

    u_centroid_divider : entity work.unsigned_iterative_divider
        generic map (
            NUMERATOR_WIDTH => DIV_NUM_WIDTH,
            DENOMINATOR_WIDTH => DIV_DEN_WIDTH,
            QUOTIENT_WIDTH => 18
        )
        port map (
            clk => clk,
            rst => rst,
            start => divider_start,
            numerator => divider_numerator,
            denominator => divider_denominator,
            quotient => divider_quotient,
            busy => divider_busy,
            done => divider_done
        );

    process(clk)
        variable root_value : label_t;
        variable intensity_value : integer;
        variable pixel_address : integer;
    begin
        if rising_edge(clk) then
            star_valid_reg <= '0';
            done_reg <= '0';
            divider_start <= '0';

            if rst = '1' then
                state <= IDLE;
                ready_toggle_prev <= frame_ready_toggle;
                line_a <= (others => 0);
                line_b <= (others => 0);
                neighbors <= (others => 0);
                roots <= (others => 0);
                neighbor_index <= 0;
                merge_index <= 0;
                merge_root_label <= 0;
                walk_label <= 0;
                walk_steps <= 0;
                target_label <= 0;
                scan_x <= 0;
                scan_y <= 0;
                next_label <= 1;
                result_label <= 1;
                centroid_label <= 0;
                pixel_reg <= (others => '0');
                rd_addr_reg <= (others => '0');
                star_index_reg <= (others => '0');
                centroid_x_reg <= (others => '0');
                centroid_y_reg <= (others => '0');
                star_area_reg <= (others => '0');
                star_intensity_reg <= (others => '0');
                star_count_reg <= (others => '0');
                busy_reg <= '0';
                done_toggle_reg <= '0';
                overflow_reg <= '0';
                divider_numerator <= (others => '0');
                divider_denominator <= (others => '0');
            else
                case state is
                    when IDLE =>
                        busy_reg <= '0';

                        if frame_ready_toggle /= ready_toggle_prev then
                            ready_toggle_prev <= frame_ready_toggle;
                            line_a <= (others => 0);
                            line_b <= (others => 0);
                            scan_x <= 0;
                            scan_y <= 0;
                            next_label <= 1;
                            result_label <= 1;
                            star_count_reg <= (others => '0');
                            overflow_reg <= '0';
                            busy_reg <= '1';
                            state <= SET_PIXEL_ADDRESS;
                        end if;

                    when SET_PIXEL_ADDRESS =>
                        busy_reg <= '1';
                        pixel_address := scan_y * FRAME_WIDTH + scan_x;
                        rd_addr_reg <= to_unsigned(pixel_address, rd_addr_reg'length);
                        state <= WAIT_PIXEL_DATA;

                    when WAIT_PIXEL_DATA =>
                        busy_reg <= '1';
                        state <= EVALUATE_PIXEL;

                    when EVALUATE_PIXEL =>
                        busy_reg <= '1';
                        pixel_reg <= unsigned(rd_data);

                        if unsigned(rd_data) < unsigned(threshold) then
                            if (scan_y mod 2) = 0 then
                                line_a(scan_x) <= 0;
                            else
                                line_b(scan_x) <= 0;
                            end if;
                            state <= ADVANCE_PIXEL;
                        else
                            neighbors <= (others => 0);
                            roots <= (others => 0);

                            if (scan_y mod 2) = 0 then
                                if scan_x > 0 then
                                    neighbors(0) <= line_a(scan_x - 1);
                                    neighbors(1) <= line_b(scan_x - 1);
                                end if;
                                if scan_y > 0 then
                                    neighbors(2) <= line_b(scan_x);
                                    if scan_x < FRAME_WIDTH - 1 then
                                        neighbors(3) <= line_b(scan_x + 1);
                                    end if;
                                end if;
                            else
                                if scan_x > 0 then
                                    neighbors(0) <= line_b(scan_x - 1);
                                    neighbors(1) <= line_a(scan_x - 1);
                                end if;
                                neighbors(2) <= line_a(scan_x);
                                if scan_x < FRAME_WIDTH - 1 then
                                    neighbors(3) <= line_a(scan_x + 1);
                                end if;
                            end if;

                            neighbor_index <= 0;
                            state <= RESOLVE_NEIGHBOR;
                        end if;

                    when RESOLVE_NEIGHBOR =>
                        busy_reg <= '1';

                        if neighbors(neighbor_index) = 0 then
                            roots(neighbor_index) <= 0;
                            if neighbor_index = 3 then
                                state <= SELECT_TARGET;
                            else
                                neighbor_index <= neighbor_index + 1;
                            end if;
                        else
                            walk_label <= neighbors(neighbor_index);
                            walk_steps <= 0;
                            state <= WALK_PARENT;
                        end if;

                    when WALK_PARENT =>
                        busy_reg <= '1';

                        if parent_table(walk_label) = walk_label then
                            roots(neighbor_index) <= walk_label;
                            if neighbor_index = 3 then
                                state <= SELECT_TARGET;
                            else
                                neighbor_index <= neighbor_index + 1;
                                state <= RESOLVE_NEIGHBOR;
                            end if;
                        elsif parent_table(walk_label) = 0 or walk_steps = MAX_LABELS then
                            roots(neighbor_index) <= 0;
                            overflow_reg <= '1';
                            if neighbor_index = 3 then
                                state <= SELECT_TARGET;
                            else
                                neighbor_index <= neighbor_index + 1;
                                state <= RESOLVE_NEIGHBOR;
                            end if;
                        else
                            walk_label <= parent_table(walk_label);
                            walk_steps <= walk_steps + 1;
                        end if;

                    when SELECT_TARGET =>
                        busy_reg <= '1';
                        target_label <= 0;
                        neighbor_index <= 0;
                        state <= SELECT_TARGET_STEP;

                    when SELECT_TARGET_STEP =>
                        busy_reg <= '1';

                        if roots(neighbor_index) /= 0 and
                           (target_label = 0 or roots(neighbor_index) < target_label) then
                            target_label <= roots(neighbor_index);
                        end if;

                        if neighbor_index = 3 then
                            state <= PREPARE_TARGET;
                        else
                            neighbor_index <= neighbor_index + 1;
                        end if;

                    when PREPARE_TARGET =>
                        busy_reg <= '1';

                        if target_label = 0 then
                            if next_label <= MAX_LABELS then
                                target_label <= next_label;
                                parent_table(next_label) <= next_label;
                                area_table(next_label) <= (others => '0');
                                sum_i_table(next_label) <= (others => '0');
                                sum_xi_table(next_label) <= (others => '0');
                                sum_yi_table(next_label) <= (others => '0');
                                next_label <= next_label + 1;
                                state <= ACCUMULATE_PIXEL;
                            else
                                overflow_reg <= '1';
                                state <= DROP_PIXEL;
                            end if;
                        else
                            merge_index <= 0;
                            state <= MERGE_ROOTS;
                        end if;

                    when MERGE_ROOTS =>
                        busy_reg <= '1';
                        merge_root_label <= roots(merge_index);
                        state <= APPLY_MERGE;

                    when APPLY_MERGE =>
                        busy_reg <= '1';
                        root_value := merge_root_label;

                        if root_value /= 0 and root_value /= target_label and
                           parent_table(root_value) = root_value then
                            parent_table(root_value) <= target_label;
                            area_table(target_label) <= area_table(target_label) + area_table(root_value);
                            sum_i_table(target_label) <= sum_i_table(target_label) + sum_i_table(root_value);
                            sum_xi_table(target_label) <= sum_xi_table(target_label) + sum_xi_table(root_value);
                            sum_yi_table(target_label) <= sum_yi_table(target_label) + sum_yi_table(root_value);
                        end if;

                        if merge_index = 3 then
                            state <= ACCUMULATE_PIXEL;
                        else
                            merge_index <= merge_index + 1;
                        end if;

                    when ACCUMULATE_PIXEL =>
                        busy_reg <= '1';
                        intensity_value := to_integer(pixel_reg);

                        if (scan_y mod 2) = 0 then
                            line_a(scan_x) <= target_label;
                        else
                            line_b(scan_x) <= target_label;
                        end if;

                        area_table(target_label) <= area_table(target_label) + 1;
                        sum_i_table(target_label) <=
                            sum_i_table(target_label) + resize(pixel_reg, sum_i_table(target_label)'length);
                        sum_xi_table(target_label) <=
                            sum_xi_table(target_label) +
                            to_unsigned(scan_x * intensity_value, sum_xi_table(target_label)'length);
                        sum_yi_table(target_label) <=
                            sum_yi_table(target_label) +
                            to_unsigned(scan_y * intensity_value, sum_yi_table(target_label)'length);
                        state <= ADVANCE_PIXEL;

                    when DROP_PIXEL =>
                        busy_reg <= '1';
                        if (scan_y mod 2) = 0 then
                            line_a(scan_x) <= 0;
                        else
                            line_b(scan_x) <= 0;
                        end if;
                        state <= ADVANCE_PIXEL;

                    when ADVANCE_PIXEL =>
                        busy_reg <= '1';

                        if scan_x = FRAME_WIDTH - 1 then
                            scan_x <= 0;
                            if scan_y = FRAME_HEIGHT - 1 then
                                result_label <= 1;
                                state <= SCAN_RESULTS;
                            else
                                scan_y <= scan_y + 1;
                                state <= SET_PIXEL_ADDRESS;
                            end if;
                        else
                            scan_x <= scan_x + 1;
                            state <= SET_PIXEL_ADDRESS;
                        end if;

                    when SCAN_RESULTS =>
                        busy_reg <= '1';

                        if result_label >= next_label or result_label > MAX_LABELS then
                            state <= DONE_STATE;
                        elsif parent_table(result_label) = result_label and
                              to_integer(area_table(result_label)) >= MIN_AREA and
                              to_integer(area_table(result_label)) <= MAX_AREA and
                              sum_i_table(result_label) /= 0 then
                            centroid_label <= result_label;
                            divider_numerator <= shift_left(
                                resize(sum_xi_table(result_label), DIV_NUM_WIDTH), 8);
                            divider_denominator <= sum_i_table(result_label);
                            divider_start <= '1';
                            state <= WAIT_DIVIDE_X;
                        else
                            result_label <= result_label + 1;
                        end if;

                    when WAIT_DIVIDE_X =>
                        busy_reg <= '1';

                        if divider_done = '1' then
                            centroid_x_reg <= divider_quotient;
                            divider_numerator <= shift_left(
                                resize(sum_yi_table(centroid_label), DIV_NUM_WIDTH), 8);
                            divider_denominator <= sum_i_table(centroid_label);
                            divider_start <= '1';
                            state <= WAIT_DIVIDE_Y;
                        end if;

                    when WAIT_DIVIDE_Y =>
                        busy_reg <= '1';

                        if divider_done = '1' then
                            centroid_y_reg <= divider_quotient;
                            state <= EMIT_STAR;
                        end if;

                    when EMIT_STAR =>
                        busy_reg <= '1';
                        star_valid_reg <= '1';
                        star_index_reg <= star_count_reg;
                        star_area_reg <= area_table(centroid_label);
                        star_intensity_reg <= sum_i_table(centroid_label);
                        star_count_reg <= star_count_reg + 1;
                        result_label <= result_label + 1;
                        state <= SCAN_RESULTS;

                    when DONE_STATE =>
                        busy_reg <= '0';
                        done_reg <= '1';
                        done_toggle_reg <= not done_toggle_reg;
                        state <= IDLE;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture;
