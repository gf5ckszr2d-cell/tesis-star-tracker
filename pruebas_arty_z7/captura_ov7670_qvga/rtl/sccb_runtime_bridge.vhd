library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Same FCLK domain as PS EMIO. The ARM holds command fields until acknowledgement.
-- control: req toggle[1], read[2], register[15:8], value[23:16].
-- status: ack toggle[0], busy[1], NACK[2], rejected[3], rx[15:8].
entity sccb_runtime_bridge is
    port (clk, rst, available : in std_logic;
          control : in std_logic_vector(63 downto 0);
          status : out std_logic_vector(31 downto 0);
          active, bus_start, bus_rw : out std_logic;
          byte0, byte1 : out std_logic_vector(7 downto 0);
          count : out unsigned(1 downto 0);
          bus_busy, bus_done, bus_error : in std_logic;
          bus_rx : in std_logic_vector(7 downto 0));
end;
architecture rtl of sccb_runtime_bridge is
    type state_t is (IDLE, START_POINTER, WAIT_POINTER, WAIT_FREE, START_READ, WAIT_READ);
    signal state : state_t := IDLE;
    signal seen, ack, err, rejected, reading : std_logic := '0';
    signal reg_addr, reg_value, result : std_logic_vector(7 downto 0) := (others=>'0');
begin
    active <= '0' when state=IDLE else '1';
    bus_start <= '1' when state=START_POINTER or state=START_READ else '0';
    bus_rw <= '1' when state=START_READ or state=WAIT_READ else '0';
    byte0 <= reg_addr; byte1 <= reg_value;
    count <= to_unsigned(1,2) when reading='1' else to_unsigned(2,2);
    status <= x"D3" & x"00" & result & "0000" & rejected & err &
              '0' & ack when state=IDLE else
              x"D3" & x"00" & result & "0000" & rejected & err & '1' & ack;
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                state<=IDLE; seen<='0'; ack<='0'; err<='0'; rejected<='0';
                reading<='0'; reg_addr<=(others=>'0'); reg_value<=(others=>'0'); result<=(others=>'0');
            else
                case state is
                    when IDLE =>
                        if control(1)/=seen then
                            seen<=control(1); err<='0'; rejected<='0';
                            if available='0' or bus_busy='1' then
                                rejected<='1'; ack<=control(1);
                            else
                                reg_addr<=control(15 downto 8); reg_value<=control(23 downto 16);
                                reading<=control(2); state<=START_POINTER;
                            end if;
                        end if;
                    when START_POINTER => state<=WAIT_POINTER;
                    when WAIT_POINTER =>
                        if bus_done='1' then
                            if bus_error='1' then err<='1'; ack<=seen; state<=IDLE;
                            elsif reading='1' then state<=WAIT_FREE;
                            else result<=reg_value; ack<=seen; state<=IDLE; end if;
                        end if;
                    when WAIT_FREE => if bus_busy='0' then state<=START_READ; end if;
                    when START_READ => state<=WAIT_READ;
                    when WAIT_READ =>
                        if bus_done='1' then result<=bus_rx; err<=bus_error; ack<=seen; state<=IDLE; end if;
                end case;
            end if;
        end if;
    end process;
end;
