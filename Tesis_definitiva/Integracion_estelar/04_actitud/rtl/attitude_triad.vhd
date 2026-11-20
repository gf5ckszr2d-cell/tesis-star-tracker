library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.attitude_math_pkg.all;
use work.g5_star_catalog_pkg.all;



entity attitude_triad is
  port(clk,rst,frame_start,match_valid:in std_logic;
       match_ray:in std_logic_vector(47 downto 0);
       match_catalog_index:in unsigned(8 downto 0);
       solve,identification_ok:in std_logic;
       quaternion:out vec4_t; busy,done,valid:out std_logic);
end;
architecture rtl of attitude_triad is
  type state_t is (IDLE,PAIR_SCAN,CROSS_MUL,CROSS_SUB,PAIR_SQUARE,PAIR_SUM,PAIR_DECIDE,NORM_START,NORM_WAIT,MATRIX_BUILD,MATRIX_SUM,QUAT_TRACE,QUAT_CANDIDATES,QUAT_SELECT,QUAT_BUILD,CHECK_RESIDUAL,RES_SUM,RES_DIFF,RES_SQUARE,RES_TOTAL,RES_DECIDE,FINISH);
  type vectors_t is array(0 to 7) of vec3_t;
  signal obs,ref:vectors_t:=(others=>(others=>(others=>'0')));
  signal count:natural range 0 to 8:=0;
  signal i,j,ai,aj:natural range 0 to 7:=0;
  signal best:unsigned(63 downto 0):=(others=>'0');
  signal state:state_t:=IDLE;
  signal norm_start_s,norm_done,norm_valid:std_logic:='0';
  signal norm_in,norm_out,qraw,qout:vec4_t:=(others=>(others=>'0'));
  signal phase:natural range 0 to 4:=0;
  signal b1,b2,b3,r1,r2,r3:vec3_t:=(others=>(others=>'0'));
  signal matrix:mat3_t:=(others=>(others=>'0'));
  signal check_index:natural range 0 to 7:=0;
  signal valid_reg:std_logic:='0';
  signal cross_reg,pred_reg,delta_reg:vec3_t:=(others=>(others=>'0'));
  type sq_t is array(0 to 2) of unsigned(35 downto 0);
  signal pair_squares,error_squares:sq_t:=(others=>(others=>'0'));
  signal pair_total,error_total:unsigned(63 downto 0):=(others=>'0');
  signal products1,products2,products3:vec3_t:=(others=>(others=>'0'));
  signal cell_p1,cell_p2,cell_p3:fixed_t:=(others=>'0');
  signal cell_row,cell_col:natural range 0 to 2:=0;
  signal cell_index:natural range 0 to 8:=0;
  signal cross_a,cross_b,xprod1,xprod2:vec3_t:=(others=>(others=>'0'));
  signal cross_to_norm:boolean:=false;
  signal trace_reg:fixed_t:=(others=>'0');
  signal qparts:vec4_t:=(others=>(others=>'0'));
  signal qbranch:natural range 0 to 3:=0;
  attribute DONT_TOUCH:string;
  attribute DONT_TOUCH of norm_in:signal is "TRUE";
  attribute DONT_TOUCH of cross_a:signal is "TRUE";
  attribute DONT_TOUCH of cross_b:signal is "TRUE";
  attribute DONT_TOUCH of xprod1:signal is "TRUE";
  attribute DONT_TOUCH of xprod2:signal is "TRUE";
  attribute DONT_TOUCH of trace_reg:signal is "TRUE";
  attribute DONT_TOUCH of qparts:signal is "TRUE";
begin
  quaternion<=qout;valid<=valid_reg;
  busy<='0' when state=IDLE else '1';
  u_norm:entity work.normalize4 port map(clk,rst,norm_start_s,norm_in,norm_out,norm_done,norm_valid);
  process(clk)
    variable cr,pred:vec3_t;
    variable norm2,residual:unsigned(63 downto 0);
    variable delta:fixed_t;
    variable tr,t0,t1,t2,t3:fixed_t;
  begin
    if rising_edge(clk) then
      done<='0';norm_start_s<='0';
      if rst='1' then state<=IDLE;count<=0;valid_reg<='0';qout<=(others=>(others=>'0'));
      elsif frame_start='1' then count<=0;valid_reg<='0';state<=IDLE;qout<=(others=>(others=>'0'));
      else
        if match_valid='1' and count<8 and state=IDLE then
          assert to_integer(match_catalog_index)<G5_STAR_COUNT report "Indice de catalogo fuera de rango" severity failure;
          obs(count)<=unpack(match_ray);ref(count)<=unpack(G5_STAR_CATALOG(to_integer(match_catalog_index)));count<=count+1;
        end if;
        case state is
          when IDLE=>
            if solve='1' then
              valid_reg<='0';qout<=(others=>(others=>'0'));
              if identification_ok='0' or count<5 then state<=FINISH;
              else i<=0;j<=1;ai<=0;aj<=1;best<=(others=>'0');state<=PAIR_SCAN;end if;
            end if;
          when PAIR_SCAN=>
            cross_a<=obs(i);cross_b<=obs(j);cross_to_norm<=false;state<=CROSS_MUL;
          when CROSS_MUL=>
            xprod1<=(mul(cross_a(1),cross_b(2)),mul(cross_a(2),cross_b(0)),mul(cross_a(0),cross_b(1)));
            xprod2<=(mul(cross_a(2),cross_b(1)),mul(cross_a(0),cross_b(2)),mul(cross_a(1),cross_b(0)));
            state<=CROSS_SUB;
          when CROSS_SUB=>
            for k in 0 to 2 loop cr(k):=xprod1(k)-xprod2(k);end loop;
            if cross_to_norm then norm_in<=extend(cr);norm_start_s<='1';state<=NORM_WAIT;
            else cross_reg<=cr;state<=PAIR_SQUARE;end if;
          when PAIR_SQUARE=>
            for k in 0 to 2 loop pair_squares(k)<=unsigned(resize(cross_reg(k),18)*resize(cross_reg(k),18));end loop;
            state<=PAIR_SUM;
          when PAIR_SUM=>
            pair_total<=resize(pair_squares(0),64)+resize(pair_squares(1),64)+resize(pair_squares(2),64);state<=PAIR_DECIDE;
          when PAIR_DECIDE=>
            if pair_total>best then best<=pair_total;ai<=i;aj<=j;end if;
            if j+1<count then j<=j+1;state<=PAIR_SCAN;
            elsif i+2<count then i<=i+1;j<=i+2;state<=PAIR_SCAN;
            else phase<=0;state<=NORM_START;end if;
          when NORM_START=>

            if best<1000000 then state<=FINISH;
            else
              if phase=2 or phase=3 then
                if phase=2 then cross_a<=obs(ai);cross_b<=obs(aj);
                else cross_a<=ref(ai);cross_b<=ref(aj);end if;
                cross_to_norm<=true;state<=CROSS_MUL;
              else
                case phase is
                  when 0=>norm_in<=extend(obs(ai));
                  when 1=>norm_in<=extend(ref(ai));
                  when others=>norm_in<=qraw;
                end case;
                norm_start_s<='1';state<=NORM_WAIT;
              end if;
            end if;
          when NORM_WAIT=>
            if norm_done='1' then
              if norm_valid='0' then state<=FINISH;
              else
                case phase is
                  when 0=>b1<=first3(norm_out);
                  when 1=>r1<=first3(norm_out);
                  when 2=>b2<=first3(norm_out);
                  when 3=>r2<=first3(norm_out);b3<=cross(b1,b2);r3<=cross(r1,first3(norm_out));
                  when others=>
                    if norm_out(0)<0 then qout(0)<=-norm_out(0); for k in 1 to 3 loop qout(k)<=norm_out(k);end loop;
                    else qout(0)<=norm_out(0); for k in 1 to 3 loop qout(k)<=-norm_out(k);end loop;end if;
                end case;
                if phase=3 then
                  cell_row<=0;cell_col<=0;cell_index<=0;state<=MATRIX_BUILD;
                elsif phase=4 then check_index<=0;valid_reg<='1';state<=CHECK_RESIDUAL;
                else phase<=phase+1;state<=NORM_START;end if;
              end if;
            end if;
          when MATRIX_BUILD=>
            cell_p1<=mul(b1(cell_row),r1(cell_col));
            cell_p2<=mul(b2(cell_row),r2(cell_col));
            cell_p3<=mul(b3(cell_row),r3(cell_col));
            state<=MATRIX_SUM;
          when MATRIX_SUM=>
            matrix(cell_index)<=cell_p1+cell_p2+cell_p3;
            if cell_index=8 then
              state<=QUAT_TRACE;
            else
              cell_index<=cell_index+1;
              if cell_col=2 then cell_col<=0;cell_row<=cell_row+1;
              else cell_col<=cell_col+1;end if;
              state<=MATRIX_BUILD;
            end if;
          when QUAT_TRACE=>
            trace_reg<=matrix(0)+matrix(4)+matrix(8);state<=QUAT_CANDIDATES;
          when QUAT_CANDIDATES=>
            qparts(0)<=to_signed(32768,32)+trace_reg;
            qparts(1)<=to_signed(32768,32)+shift_left(matrix(0),1)-trace_reg;
            qparts(2)<=to_signed(32768,32)+shift_left(matrix(4),1)-trace_reg;
            qparts(3)<=to_signed(32768,32)+shift_left(matrix(8),1)-trace_reg;
            state<=QUAT_SELECT;
          when QUAT_SELECT=>
            if qparts(0)>=qparts(1) and qparts(0)>=qparts(2) and qparts(0)>=qparts(3) then qbranch<=0;
            elsif qparts(1)>=qparts(2) and qparts(1)>=qparts(3) then qbranch<=1;
            elsif qparts(2)>=qparts(3) then qbranch<=2;else qbranch<=3;end if;
            state<=QUAT_BUILD;
          when QUAT_BUILD=>
            if qbranch=0 then qraw<=(qparts(0),matrix(7)-matrix(5),matrix(2)-matrix(6),matrix(3)-matrix(1));
            elsif qbranch=1 then qraw<=(matrix(7)-matrix(5),qparts(1),matrix(1)+matrix(3),matrix(2)+matrix(6));
            elsif qbranch=2 then qraw<=(matrix(2)-matrix(6),matrix(1)+matrix(3),qparts(2),matrix(5)+matrix(7));
            else qraw<=(matrix(3)-matrix(1),matrix(2)+matrix(6),matrix(5)+matrix(7),qparts(3));end if;
            phase<=4;state<=NORM_START;
          when CHECK_RESIDUAL=>
            for row in 0 to 2 loop
              products1(row)<=mul(matrix(row*3),ref(check_index)(0));
              products2(row)<=mul(matrix(row*3+1),ref(check_index)(1));
              products3(row)<=mul(matrix(row*3+2),ref(check_index)(2));
            end loop;
            state<=RES_SUM;
          when RES_SUM=>
            for row in 0 to 2 loop pred_reg(row)<=products1(row)+products2(row)+products3(row);end loop;
            state<=RES_DIFF;
          when RES_DIFF=>
            for row in 0 to 2 loop delta_reg(row)<=pred_reg(row)-obs(check_index)(row);end loop;
            state<=RES_SQUARE;
          when RES_SQUARE=>
            for row in 0 to 2 loop error_squares(row)<=unsigned(resize(delta_reg(row),18)*resize(delta_reg(row),18));end loop;
            state<=RES_TOTAL;
          when RES_TOTAL=>
            error_total<=resize(error_squares(0),64)+resize(error_squares(1),64)+resize(error_squares(2),64);state<=RES_DECIDE;
          when RES_DECIDE=>

            if error_total>65536 then valid_reg<='0';end if;
            if check_index+1<count then check_index<=check_index+1;state<=CHECK_RESIDUAL;else state<=FINISH;end if;
          when FINISH=>
            if valid_reg='0' then qout<=(others=>(others=>'0'));end if;
            done<='1';state<=IDLE;
        end case;
      end if;
    end if;
  end process;
end;
