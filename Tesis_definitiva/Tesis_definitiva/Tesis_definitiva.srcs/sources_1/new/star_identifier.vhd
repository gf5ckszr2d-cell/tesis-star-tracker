library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.g5_star_catalog_pkg.all;
use work.g5_pair_lookup_pkg.all;
use work.g5_ray_lut_pkg.all;


entity star_identifier is
  generic(CX_Q8:integer:=CFG_CX_Q8; CY_Q8:integer:=CFG_CY_Q8; SCALE_X:integer:=CFG_SCALE_X; SCALE_Y:integer:=CFG_SCALE_Y);
  port (
    clk, rst : in std_logic;
    list_ready : in std_logic;
    list_overflow : in std_logic;
    star_count : in unsigned(7 downto 0);
    rd_index : out unsigned(7 downto 0);
    rd_valid : in std_logic;
    rd_x_q8_8 : in unsigned(17 downto 0);
    rd_y_q8_8 : in unsigned(17 downto 0);
    rd_intensity : in unsigned(24 downto 0);
    busy, done, success : out std_logic;
    identified_count : out unsigned(3 downto 0);
    match_valid : out std_logic;
    match_star_index : out unsigned(7 downto 0);
    match_catalog_index : out unsigned(8 downto 0);
    match_ray : out std_logic_vector(47 downto 0) := (others=>'0')
  );
end entity;

architecture rtl of star_identifier is
  constant MAX_OBS : natural := 8;
  constant MIN_IDENTIFIED : natural := CFG_MIN_IDENTIFIED;
  constant NO_ID : integer := -1;
  type state_t is (
    IDLE, LOAD_REQ, LOAD_WAIT, LOAD_TAKE, LOAD_RANK, LOAD_COMPARE, LOAD_INSERT, LOAD_NEXT,
    PREP_DIFF, PREP_SCALE, PREP_SQUARE, PREP_RADIUS_SUM,
    PREP_RADIUS, PREP_NORM,
    PREP_PRODUCT, PREP_ROUND, PREP_FINAL,
    PREP_PAIR_READ, PREP_PAIR, PREP_PAIR_SQUARE, PREP_PAIR_SUM, PREP_BIN_INIT, PREP_BIN_LOOKUP,
    PREP_BIN_COMPARE, PREP_BIN_STORE,
    ANCHOR_START, PAIR_FETCH, PAIR_CHECK, PAIR_DECIDE,
    HYP_START, HYP_STAR,
    CAND_START, CAND_FETCH, CAND_CHECK, CAND_SQUARE, CAND_SUM, CAND_DIFF, CAND_TOLERANCE, CAND_DECIDE,
    HYP_SCORE, PAIR_NEXT,
    EMIT, FINISH
  );
  type star_t is record
    x : unsigned(17 downto 0);
    y : unsigned(17 downto 0);
    intensity : unsigned(24 downto 0);
    source_index : unsigned(7 downto 0);
  end record;
  constant EMPTY_STAR : star_t := (
    x => (others => '0'), y => (others => '0'),
    intensity => (others => '0'), source_index => (others => '0'));
  type star_array_t is array (0 to MAX_OBS - 1) of star_t;
  type ray_array_t is array (0 to MAX_OBS - 1) of std_logic_vector(47 downto 0);
  type observed_pairs_t is array (0 to 63) of std_logic_vector(31 downto 0);
  type id_array_t is array (0 to MAX_OBS - 1) of integer range -1 to G5_STAR_COUNT - 1;

  function chord_q24(a, b : std_logic_vector(47 downto 0)) return unsigned is
    variable dx,dy,dz : signed(16 downto 0);
    variable distance : unsigned(35 downto 0);
  begin

    dx:=resize(signed(a(47 downto 32)),17)-resize(signed(b(47 downto 32)),17);
    dy:=resize(signed(a(31 downto 16)),17)-resize(signed(b(31 downto 16)),17);
    dz:=resize(signed(a(15 downto 0)),17)-resize(signed(b(15 downto 0)),17);
    distance:=resize(unsigned(dx*dx),36)+resize(unsigned(dy*dy),36)+resize(unsigned(dz*dz),36);
    return resize(shift_right(distance,6),24);
  end function;

  function abs_diff(a, b : unsigned(23 downto 0)) return unsigned is
  begin
    if a >= b then return a - b; end if;
    return b - a;
  end function;

  signal state : state_t := IDLE;
  signal list_ready_prev : std_logic := '0';
  signal rd_index_reg : unsigned(7 downto 0) := (others => '0');
  signal done_reg, success_reg, match_valid_reg : std_logic := '0';
  signal match_star_index_reg : unsigned(7 downto 0) := (others => '0');
  signal match_catalog_index_reg : unsigned(8 downto 0) := (others => '0');
  signal identified_count_reg : unsigned(3 downto 0) := (others => '0');
  signal stars : star_array_t := (others => EMPTY_STAR);
  signal pending_star : star_t := EMPTY_STAR;
  signal rank_index : integer range 0 to MAX_OBS - 1 := 0;
  signal rank_intensity : unsigned(24 downto 0) := (others => '0');
  signal rays : ray_array_t := (others => (others => '0'));
  signal observed_pairs : observed_pairs_t;
  signal candidate_obs_address : unsigned(5 downto 0) := (others => '0');
  signal observed_pair_read : std_logic_vector(31 downto 0) := (others => '0');
  signal current_ids, best_ids : id_array_t := (others => NO_ID);
  signal input_count : integer range 0 to 64 := 0;
  signal selected_count : integer range 0 to MAX_OBS := 0;
  signal load_index : integer range 0 to 64 := 0;
  signal prep_index : integer range 0 to MAX_OBS := 0;
  signal dx_reg, dy_reg : integer range -131072 to 131072 := 0;
  signal ux_reg, uy_reg : integer range -16384 to 16384 := 0;
  signal sqx_reg, sqy_reg : integer range 0 to 268435456 := 0;
  signal radius_sum_reg : integer range 0 to 536870912 := 0;
  signal radius_index_reg : integer range 0 to 511 := 0;
  signal norm_reg : integer range 0 to 32767 := 0;
  signal product_x_reg, product_y_reg : integer := 0;
  signal rx_reg, ry_reg : integer range -32768 to 32767 := 0;
  signal pair_i, pair_j : integer range 0 to MAX_OBS - 1 := 0;
  signal pair_a_ray, pair_b_ray : std_logic_vector(47 downto 0) := (others => '0');
  signal pair_chord_reg : unsigned(23 downto 0) := (others => '0');
  signal bin_low, bin_high, bin_mid : integer range 0 to 128 := 0;
  signal bin_step : integer range 0 to 8 := 0;
  signal bin_boundary : unsigned(23 downto 0) := (others => '0');
  signal anchor_i, anchor_j : integer range 0 to MAX_OBS - 1 := 0;
  signal anchor_chord_reg : unsigned(23 downto 0) := (others => '0');
  signal anchor_bin_reg : integer range 0 to 128 := 0;
  signal pair_address, pair_end : integer range 0 to G5_PAIR_COUNT := 0;
  signal pair_word : std_logic_vector(47 downto 0) := (others => '0');
  signal pair_difference_reg : unsigned(23 downto 0) := (others => '0');
  signal catalog_a, catalog_b : integer range 0 to G5_STAR_COUNT - 1 := 0;
  signal orientation : integer range 0 to 1 := 0;
  signal hypothesis_k : integer range 0 to MAX_OBS := 0;
  signal candidate_c : integer range 0 to G5_STAR_COUNT := 0;
  signal check_l : integer range 0 to MAX_OBS := 0;
  signal candidate_error, candidate_best_error, current_error, best_error : integer := 0;
  signal candidate_best_id : integer range -1 to G5_STAR_COUNT - 1 := NO_ID;
  signal current_count, best_count : integer range 0 to MAX_OBS := 0;
  signal catalog_l_ray, catalog_c_ray : std_logic_vector(47 downto 0) := (others => '0');
  signal catalog_chord_reg, candidate_difference_reg : unsigned(23 downto 0) := (others => '0');
  signal emit_index : integer range 0 to MAX_OBS := 0;
  signal chord_dx,chord_dy,chord_dz:signed(16 downto 0):=(others=>'0');
  signal chord_sx,chord_sy,chord_sz:unsigned(33 downto 0):=(others=>'0');
  signal candidate_bin_reg:integer range 0 to 128:=0;
  signal candidate_tolerance_reg:unsigned(23 downto 0):=(others=>'0');
  attribute DONT_TOUCH:string;
  attribute DONT_TOUCH of chord_dx:signal is "TRUE";
  attribute DONT_TOUCH of chord_dy:signal is "TRUE";
  attribute DONT_TOUCH of chord_dz:signal is "TRUE";
  attribute DONT_TOUCH of chord_sx:signal is "TRUE";
  attribute DONT_TOUCH of chord_sy:signal is "TRUE";
  attribute DONT_TOUCH of chord_sz:signal is "TRUE";
  attribute DONT_TOUCH of candidate_bin_reg:signal is "TRUE";
  attribute DONT_TOUCH of candidate_tolerance_reg:signal is "TRUE";
  attribute ram_style : string;
  attribute ram_style of observed_pairs : signal is "distributed";
begin
  assert G5_STAR_COUNT <= 512 report "Catalogo excede direccion de 9 bits" severity failure;
  rd_index <= rd_index_reg;
  busy <= '0' when state = IDLE else '1';
  done <= done_reg;
  success <= success_reg and list_ready;
  identified_count <= identified_count_reg when list_ready = '1' else (others => '0');
  match_valid <= match_valid_reg;
  match_star_index <= match_star_index_reg;
  match_catalog_index <= match_catalog_index_reg;

  process(clk)
  begin
    if rising_edge(clk) then
      if state = PREP_BIN_STORE then
        observed_pairs(pair_i * 8 + pair_j) <= std_logic_vector(to_unsigned(bin_low, 8)) &
          std_logic_vector(pair_chord_reg);
      end if;
      observed_pair_read <= observed_pairs(to_integer(candidate_obs_address));
    end if;
  end process;

  process(clk)
    variable candidate_used : boolean;
    variable catalog_chord : unsigned(23 downto 0);
    variable a, b : integer;
  begin
    if rising_edge(clk) then
      done_reg <= '0';
      match_valid_reg <= '0';
      list_ready_prev <= list_ready;
      if rst = '1' then
        state <= IDLE;
        list_ready_prev <= '0';
        rd_index_reg <= (others => '0');
        success_reg <= '0';
        identified_count_reg <= (others => '0');
        selected_count <= 0;
      elsif list_ready = '0' and state /= IDLE then
        state <= IDLE;
        success_reg <= '0';
        identified_count_reg <= (others => '0');
      else
        case state is
          when IDLE =>
            if list_ready = '1' and list_ready_prev = '0' then
              success_reg <= '0';
              identified_count_reg <= (others => '0');
              selected_count <= 0;
              input_count <= to_integer(star_count);
              load_index <= 0;
              best_count <= 0;
              best_error <= integer'high;
              best_ids <= (others => NO_ID);
              anchor_chord_reg <= (others => '0');
              anchor_bin_reg <= 0;
              anchor_i <= 0;
              anchor_j <= 1;
              if list_overflow = '1' or star_count = 0 then
                state <= FINISH;
              else
                state <= LOAD_REQ;
              end if;
            end if;

          when LOAD_REQ =>
            rd_index_reg <= to_unsigned(load_index, 8);
            state <= LOAD_WAIT;
          when LOAD_WAIT =>
            state <= LOAD_TAKE;
          when LOAD_TAKE =>
            if rd_valid = '0' then
              state <= LOAD_NEXT;
            else
              pending_star <= (rd_x_q8_8, rd_y_q8_8, rd_intensity, to_unsigned(load_index, 8));
              rank_index <= 0;
              if selected_count = 0 then state <= LOAD_INSERT;
              else state <= LOAD_RANK; end if;
            end if;

          when LOAD_RANK =>
            rank_intensity <= stars(rank_index).intensity;
            state <= LOAD_COMPARE;

          when LOAD_COMPARE =>
            if pending_star.intensity > rank_intensity then
              state <= LOAD_INSERT;
            elsif rank_index = MAX_OBS - 1 then
              state <= LOAD_NEXT;
            else
              rank_index <= rank_index + 1;
              if rank_index + 1 = selected_count then state <= LOAD_INSERT;
              else state <= LOAD_RANK; end if;
            end if;

          when LOAD_INSERT =>
            if rank_index = 0 then stars(0) <= pending_star; end if;
            for index in 1 to MAX_OBS - 1 loop
              if index = rank_index then stars(index) <= pending_star;
              elsif index > rank_index then stars(index) <= stars(index - 1); end if;
            end loop;
            if selected_count < MAX_OBS then selected_count <= selected_count + 1; end if;
            state <= LOAD_NEXT;

          when LOAD_NEXT =>
            if load_index + 1 < input_count then
              load_index <= load_index + 1;
              state <= LOAD_REQ;
            elsif selected_count < MIN_IDENTIFIED then
              state <= FINISH;
            else
              prep_index <= 0;
              state <= PREP_DIFF;
            end if;

          when PREP_DIFF =>
            dx_reg <= to_integer(stars(prep_index).x) - CX_Q8;
            dy_reg <= to_integer(stars(prep_index).y) - CY_Q8;
            state <= PREP_SCALE;
          when PREP_SCALE =>

            ux_reg <= to_integer(shift_right(to_signed(dx_reg * SCALE_X + 32768, 32), 16));
            uy_reg <= to_integer(shift_right(to_signed(dy_reg * SCALE_Y + 32768, 32), 16));
            state <= PREP_SQUARE;
          when PREP_SQUARE =>
            sqx_reg <= ux_reg * ux_reg;
            sqy_reg <= uy_reg * uy_reg;
            state <= PREP_RADIUS_SUM;
          when PREP_RADIUS_SUM =>
            radius_sum_reg <= sqx_reg + sqy_reg;
            state <= PREP_RADIUS;
          when PREP_RADIUS =>
            if radius_sum_reg / 262144 > 511 then
              success_reg<='0'; identified_count_reg<=(others=>'0'); state<=FINISH;
            else
              radius_index_reg <= radius_sum_reg / 262144;
              state <= PREP_NORM;
            end if;
          when PREP_NORM =>
            norm_reg <= to_integer(G5_INV_SQRT(radius_index_reg));
            state <= PREP_PRODUCT;
          when PREP_PRODUCT =>
            product_x_reg <= ux_reg * norm_reg;
            product_y_reg <= uy_reg * norm_reg;
            state <= PREP_ROUND;
          when PREP_ROUND =>
            rx_reg <= to_integer(shift_right(to_signed(product_x_reg + 16384, 32), 15));
            ry_reg <= to_integer(shift_right(to_signed(product_y_reg + 16384, 32), 15));
            state <= PREP_FINAL;
          when PREP_FINAL =>
            rays(prep_index) <= std_logic_vector(to_signed(rx_reg, 16)) &
              std_logic_vector(to_signed(ry_reg, 16)) &
              std_logic_vector(to_signed(norm_reg, 16));
            if prep_index + 1 < selected_count then prep_index <= prep_index + 1;
            else
              pair_i <= 0; pair_j <= 1;
            end if;
            if prep_index + 1 < selected_count then state <= PREP_DIFF;
            else state <= PREP_PAIR_READ; end if;
          when PREP_PAIR_READ =>
            pair_a_ray <= rays(pair_i);
            pair_b_ray <= rays(pair_j);
            state <= PREP_PAIR;
          when PREP_PAIR =>
            chord_dx<=resize(signed(pair_a_ray(47 downto 32)),17)-resize(signed(pair_b_ray(47 downto 32)),17);
            chord_dy<=resize(signed(pair_a_ray(31 downto 16)),17)-resize(signed(pair_b_ray(31 downto 16)),17);
            chord_dz<=resize(signed(pair_a_ray(15 downto 0)),17)-resize(signed(pair_b_ray(15 downto 0)),17);
            state<=PREP_PAIR_SQUARE;
          when PREP_PAIR_SQUARE=>
            chord_sx<=unsigned(chord_dx*chord_dx);chord_sy<=unsigned(chord_dy*chord_dy);chord_sz<=unsigned(chord_dz*chord_dz);
            state<=PREP_PAIR_SUM;
          when PREP_PAIR_SUM=>
            pair_chord_reg<=resize(shift_right(resize(chord_sx,36)+resize(chord_sy,36)+resize(chord_sz,36),6),24);
            state <= PREP_BIN_INIT;
          when PREP_BIN_INIT =>
            bin_low <= 0;
            bin_high <= 128;
            bin_step <= 0;
            state <= PREP_BIN_LOOKUP;
          when PREP_BIN_LOOKUP =>
            if bin_low < bin_high then
              bin_mid <= (bin_low + bin_high) / 2;
              bin_boundary <= G5_BOUNDARY_CHORD((bin_low + bin_high) / 2);
            end if;
            state <= PREP_BIN_COMPARE;
          when PREP_BIN_COMPARE =>
            if bin_low < bin_high then
              if pair_chord_reg >= bin_boundary then bin_low <= bin_mid + 1;
              else bin_high <= bin_mid; end if;
            end if;
            if bin_step = 7 then state <= PREP_BIN_STORE;
            else
              bin_step <= bin_step + 1;
              state <= PREP_BIN_LOOKUP;
            end if;
          when PREP_BIN_STORE =>
            if pair_chord_reg > anchor_chord_reg then
              anchor_chord_reg <= pair_chord_reg;
              anchor_bin_reg <= bin_low;
              anchor_i <= pair_i;
              anchor_j <= pair_j;
            end if;
            if pair_j + 1 < selected_count then
              pair_j <= pair_j + 1;
              state <= PREP_PAIR_READ;
            elsif pair_i + 2 < selected_count then
              pair_i <= pair_i + 1;
              pair_j <= pair_i + 2;
              state <= PREP_PAIR_READ;
            else
              state <= ANCHOR_START;
            end if;

          when ANCHOR_START =>
            if anchor_bin_reg > 0 then pair_address <= G5_PAIR_OFFSET(anchor_bin_reg - 1);
            else pair_address <= 0; end if;
            if anchor_bin_reg + 2 <= 129 then pair_end <= G5_PAIR_OFFSET(anchor_bin_reg + 2);
            else pair_end <= G5_PAIR_COUNT; end if;
            state <= PAIR_FETCH;
          when PAIR_FETCH =>
            if pair_address >= pair_end then
              emit_index <= 0;
              if best_count >= MIN_IDENTIFIED then
                success_reg <= '1';
                identified_count_reg <= to_unsigned(best_count, 4);
              end if;
              state <= EMIT;
            else
              pair_word <= G5_PAIR_ROM(pair_address);
              state <= PAIR_CHECK;
            end if;
          when PAIR_CHECK =>
            catalog_chord := unsigned(pair_word(23 downto 0));
            pair_difference_reg <= abs_diff(catalog_chord, anchor_chord_reg);
            state <= PAIR_DECIDE;
          when PAIR_DECIDE =>
            a := to_integer(unsigned(pair_word(47 downto 36)));
            b := to_integer(unsigned(pair_word(35 downto 24)));
            if a < G5_STAR_COUNT and b < G5_STAR_COUNT and
               pair_difference_reg <= G5_TOLERANCE_CHORD(anchor_bin_reg) then
              catalog_a <= a; catalog_b <= b;
              orientation <= 0;
              state <= HYP_START;
            else
              state <= PAIR_NEXT;
            end if;
          when HYP_START =>
            current_ids <= (others => NO_ID);
            if orientation = 0 then
              current_ids(anchor_i) <= catalog_a;
              current_ids(anchor_j) <= catalog_b;
            else
              current_ids(anchor_i) <= catalog_b;
              current_ids(anchor_j) <= catalog_a;
            end if;
            current_count <= 2;
            current_error <= to_integer(pair_difference_reg);
            hypothesis_k <= 0;
            state <= HYP_STAR;
          when HYP_STAR =>
            if hypothesis_k >= selected_count then
              state <= HYP_SCORE;
            elsif hypothesis_k = anchor_i or hypothesis_k = anchor_j then
              hypothesis_k <= hypothesis_k + 1;
            else
              candidate_c <= 0;
              candidate_best_id <= NO_ID;
              candidate_best_error <= integer'high;
              state <= CAND_START;
            end if;
          when CAND_START =>
            if candidate_c >= G5_STAR_COUNT then
              if candidate_best_id /= NO_ID then
                current_ids(hypothesis_k) <= candidate_best_id;
                current_count <= current_count + 1;
                current_error <= current_error + candidate_best_error;
              end if;
              hypothesis_k <= hypothesis_k + 1;
              state <= HYP_STAR;
            else
              candidate_used := false;
              for index in 0 to MAX_OBS - 1 loop
                if current_ids(index) = candidate_c then candidate_used := true; end if;
              end loop;
              if candidate_used then
                candidate_c <= candidate_c + 1;
              else
                check_l <= 0;
                candidate_error <= 0;
                state <= CAND_FETCH;
              end if;
            end if;
          when CAND_FETCH =>
            if check_l >= selected_count then
              if candidate_error < candidate_best_error then
                candidate_best_error <= candidate_error;
                candidate_best_id <= candidate_c;
              end if;
              candidate_c <= candidate_c + 1;
              state <= CAND_START;
            elsif current_ids(check_l) = NO_ID then
              check_l <= check_l + 1;
            else
              catalog_l_ray <= G5_STAR_CATALOG(current_ids(check_l));
              catalog_c_ray <= G5_STAR_CATALOG(candidate_c);
              if check_l < hypothesis_k then
                candidate_obs_address <= to_unsigned(check_l, 3) & to_unsigned(hypothesis_k, 3);
              else
                candidate_obs_address <= to_unsigned(hypothesis_k, 3) & to_unsigned(check_l, 3);
              end if;
              state <= CAND_CHECK;
            end if;
          when CAND_CHECK =>
            chord_dx<=resize(signed(catalog_l_ray(47 downto 32)),17)-resize(signed(catalog_c_ray(47 downto 32)),17);
            chord_dy<=resize(signed(catalog_l_ray(31 downto 16)),17)-resize(signed(catalog_c_ray(31 downto 16)),17);
            chord_dz<=resize(signed(catalog_l_ray(15 downto 0)),17)-resize(signed(catalog_c_ray(15 downto 0)),17);
            state<=CAND_SQUARE;
          when CAND_SQUARE=>
            chord_sx<=unsigned(chord_dx*chord_dx);chord_sy<=unsigned(chord_dy*chord_dy);chord_sz<=unsigned(chord_dz*chord_dz);
            state<=CAND_SUM;
          when CAND_SUM=>
            catalog_chord_reg<=resize(shift_right(resize(chord_sx,36)+resize(chord_sy,36)+resize(chord_sz,36),6),24);
            state <= CAND_DIFF;
          when CAND_DIFF =>
            candidate_difference_reg <= abs_diff(catalog_chord_reg,
              unsigned(observed_pair_read(23 downto 0)));
            candidate_bin_reg<=to_integer(unsigned(observed_pair_read(31 downto 24)));
            state<=CAND_TOLERANCE;
          when CAND_TOLERANCE=>
            candidate_tolerance_reg<=G5_TOLERANCE_CHORD(candidate_bin_reg);
            state <= CAND_DECIDE;
          when CAND_DECIDE =>
            if candidate_difference_reg > candidate_tolerance_reg then
              candidate_c <= candidate_c + 1;
              state <= CAND_START;
            else
              candidate_error <= candidate_error + to_integer(candidate_difference_reg);
              check_l <= check_l + 1;
              state <= CAND_FETCH;
            end if;
          when HYP_SCORE =>
            if current_count > best_count or
               (current_count = best_count and current_error < best_error) then
              best_count <= current_count;
              best_error <= current_error;
              best_ids <= current_ids;
            end if;

            if orientation = 0 then
              orientation <= 1;
              state <= HYP_START;
            else
              state <= PAIR_NEXT;
            end if;
          when PAIR_NEXT =>
            pair_address <= pair_address + 1;
            state <= PAIR_FETCH;
          when EMIT =>
            if emit_index >= selected_count then
              state <= FINISH;
            else
              if success_reg = '1' and best_ids(emit_index) /= NO_ID then
                match_valid_reg <= '1';
                match_star_index_reg <= stars(emit_index).source_index;
                match_catalog_index_reg <= to_unsigned(best_ids(emit_index), 9);
                match_ray <= rays(emit_index);
              end if;
              emit_index <= emit_index + 1;
            end if;
          when FINISH =>
            done_reg <= '1';
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
