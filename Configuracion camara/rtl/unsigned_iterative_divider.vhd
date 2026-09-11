library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity unsigned_iterative_divider is
    generic (
        NUMERATOR_WIDTH   : positive := 40;
        DENOMINATOR_WIDTH : positive := 24;
        QUOTIENT_WIDTH    : positive := 18
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        start       : in std_logic;
        numerator   : in unsigned(NUMERATOR_WIDTH - 1 downto 0);
        denominator : in unsigned(DENOMINATOR_WIDTH - 1 downto 0);

        quotient : out unsigned(QUOTIENT_WIDTH - 1 downto 0);
        busy     : out std_logic;
        done     : out std_logic
    );
end entity;

architecture rtl of unsigned_iterative_divider is

    signal numerator_reg : unsigned(NUMERATOR_WIDTH - 1 downto 0) := (others => '0');
    signal denominator_reg : unsigned(DENOMINATOR_WIDTH downto 0) := (others => '0');
    signal remainder_reg : unsigned(DENOMINATOR_WIDTH downto 0) := (others => '0');
    signal quotient_work : unsigned(NUMERATOR_WIDTH - 1 downto 0) := (others => '0');
    signal quotient_reg : unsigned(QUOTIENT_WIDTH - 1 downto 0) := (others => '0');

    signal bit_index : integer range 0 to NUMERATOR_WIDTH - 1 := 0;
    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';

begin

    quotient <= quotient_reg;
    busy <= busy_reg;
    done <= done_reg;

    process(clk)
        variable shifted_remainder : unsigned(DENOMINATOR_WIDTH downto 0);
        variable next_quotient : unsigned(NUMERATOR_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            done_reg <= '0';

            if rst = '1' then
                numerator_reg <= (others => '0');
                denominator_reg <= (others => '0');
                remainder_reg <= (others => '0');
                quotient_work <= (others => '0');
                quotient_reg <= (others => '0');
                bit_index <= 0;
                busy_reg <= '0';
            elsif start = '1' and busy_reg = '0' then
                if denominator = 0 then
                    quotient_reg <= (others => '0');
                    busy_reg <= '0';
                    done_reg <= '1';
                else
                    numerator_reg <= numerator;
                    denominator_reg <= resize(denominator, denominator_reg'length);
                    remainder_reg <= (others => '0');
                    quotient_work <= (others => '0');
                    bit_index <= NUMERATOR_WIDTH - 1;
                    busy_reg <= '1';
                end if;
            elsif busy_reg = '1' then
                shifted_remainder := shift_left(remainder_reg, 1);
                shifted_remainder(0) := numerator_reg(bit_index);
                next_quotient := quotient_work;

                if shifted_remainder >= denominator_reg then
                    shifted_remainder := shifted_remainder - denominator_reg;
                    next_quotient(bit_index) := '1';
                end if;

                remainder_reg <= shifted_remainder;
                quotient_work <= next_quotient;

                if bit_index = 0 then
                    quotient_reg <= resize(next_quotient, quotient_reg'length);
                    busy_reg <= '0';
                    done_reg <= '1';
                else
                    bit_index <= bit_index - 1;
                end if;
            end if;
        end if;
    end process;

end architecture;
