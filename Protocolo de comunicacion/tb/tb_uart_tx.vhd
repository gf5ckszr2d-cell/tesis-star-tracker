library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_tx is
end entity;

architecture sim of tb_uart_tx is

    component uart_tx is
        generic (
            CLK_FREQ_HZ : integer := 100000000;
            BAUD_RATE   : integer := 921600
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            tx_start : in std_logic;
            tx_data  : in std_logic_vector(7 downto 0);

            tx_line : out std_logic;
            busy    : out std_logic;
            done    : out std_logic
        );
    end component;

    constant CLK_PERIOD : time := 10 ns;
    constant BIT_PERIOD : time := 1 us;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal tx_start : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_line  : std_logic;
    signal busy     : std_logic;
    signal done     : std_logic;

begin

    uut : uart_tx
        generic map (
            CLK_FREQ_HZ => 100000000,
            BAUD_RATE   => 1000000
        )
        port map (
            clk => clk,
            rst => rst,

            tx_start => tx_start,
            tx_data  => tx_data,

            tx_line => tx_line,
            busy    => busy,
            done    => done
        );

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    stimulus : process
    begin
        report "Inicio de simulacion uart_tx";

        rst <= '1';
        tx_start <= '0';
        tx_data <= x"A5";

        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait until rising_edge(clk);

        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait until done = '1' for 20 us;

        assert done = '1'
            report "ERROR: timeout esperando done"
            severity failure;

        assert tx_line = '1'
            report "ERROR: tx_line no queda en idle alto"
            severity failure;

        report "Simulacion uart_tx finalizada correctamente";
        wait;
    end process;

    uart_monitor : process
    begin
        wait until tx_line = '0';
        wait for BIT_PERIOD / 2;

        assert tx_line = '0'
            report "ERROR: bit de start incorrecto"
            severity failure;

        for bit_index in 0 to 7 loop
            wait for BIT_PERIOD;
            assert tx_line = tx_data(bit_index)
                report "ERROR: bit de datos UART incorrecto"
                severity failure;
        end loop;

        wait for BIT_PERIOD;
        assert tx_line = '1'
            report "ERROR: bit de stop incorrecto"
            severity failure;

        wait;
    end process;

end architecture;
