library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.attitude_math_pkg.all;


entity normalize4 is
  port(clk,rst,start: in std_logic; data_in: in vec4_t;
       data_out: out vec4_t; done,valid: out std_logic);
end;
architecture rtl of normalize4 is
  type state_t is (IDLE,SUMSQ,SUM_ADD,ROOT_TRIAL,ROOT_SQUARE,ROOT_STEP,DIV_START,DIV_WAIT,FINISH);
  signal state:state_t:=IDLE;
  signal v,o:vec4_t:=(others=>(others=>'0'));
  signal square_sum:unsigned(63 downto 0):=(others=>'0');
  signal root,bit_value:unsigned(19 downto 0):=(others=>'0');
  signal trial_root:unsigned(19 downto 0):=(others=>'0');
  signal trial_square:unsigned(39 downto 0):=(others=>'0');
  type squares_t is array(0 to 3) of unsigned(39 downto 0);
  signal squares:squares_t:=(others=>(others=>'0'));
  signal index:natural range 0 to 3:=0;
  signal div_start_s,div_done:std_logic:='0';
  signal numerator:unsigned(35 downto 0):=(others=>'0');
  signal quotient:unsigned(17 downto 0);
  attribute DONT_TOUCH:string;
  attribute DONT_TOUCH of v:signal is "TRUE";
begin
  data_out<=o;
  u_div:entity work.unsigned_iterative_divider
    generic map(NUMERATOR_WIDTH=>36,DENOMINATOR_WIDTH=>20,QUOTIENT_WIDTH=>18)
    port map(clk=>clk,rst=>rst,start=>div_start_s,numerator=>numerator,
             denominator=>root,quotient=>quotient,busy=>open,done=>div_done);
  process(clk)
    variable q:fixed_t;
  begin
    if rising_edge(clk) then
      done<='0';div_start_s<='0';
      if rst='1' then state<=IDLE;valid<='0';o<=(others=>(others=>'0'));
      else
        case state is
          when IDLE=>
            if start='1' then v<=data_in;valid<='0';state<=SUMSQ;end if;
          when SUMSQ=>
            for k in 0 to 3 loop
              assert v(k)>=-262144 and v(k)<=262143 report "Normalizador fuera de rango" severity failure;
              squares(k)<=unsigned(resize(v(k),20)*resize(v(k),20));
            end loop;
            square_sum<=(others=>'0');index<=0;state<=SUM_ADD;
          when SUM_ADD=>
            square_sum<=square_sum+resize(squares(index),64);
            if index=3 then root<=(others=>'0');bit_value<=x"80000";state<=ROOT_TRIAL;
            else index<=index+1;end if;
          when ROOT_TRIAL=>trial_root<=root or bit_value;state<=ROOT_SQUARE;
          when ROOT_SQUARE=>trial_square<=trial_root*trial_root;state<=ROOT_STEP;
          when ROOT_STEP=>
            if trial_square<=square_sum then root<=trial_root;end if;
            bit_value<=shift_right(bit_value,1);
            if bit_value=1 then index<=0;state<=DIV_START;else state<=ROOT_TRIAL;end if;
          when DIV_START=>
            if root<16 then o<=(others=>(others=>'0'));valid<='0';state<=FINISH;
            else
              numerator<=shift_left(resize(unsigned(abs(v(index))),numerator'length),15);
              div_start_s<='1';state<=DIV_WAIT;
            end if;
          when DIV_WAIT=>
            if div_done='1' then
              q:=signed(resize(quotient,q'length));
              if q>32768 then q:=to_signed(32768,32);end if;
              if v(index)<0 then q:=-q;end if;
              o(index)<=q;
              if index=3 then valid<='1';state<=FINISH;
              else index<=index+1;state<=DIV_START;end if;
            end if;
          when FINISH=>done<='1';state<=IDLE;
        end case;
      end if;
    end if;
  end process;
end;
