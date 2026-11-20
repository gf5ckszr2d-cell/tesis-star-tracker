library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package attitude_math_pkg is
  subtype fixed_t is signed(31 downto 0);
  type vec3_t is array(0 to 2) of fixed_t;
  type vec4_t is array(0 to 3) of fixed_t;
  type mat3_t is array(0 to 8) of fixed_t;
  function mul(a,b: fixed_t) return fixed_t;
  function cross(a,b: vec3_t) return vec3_t;
  function unpack(a: std_logic_vector(47 downto 0)) return vec3_t;
  function extend(a: vec3_t) return vec4_t;
  function first3(a: vec4_t) return vec3_t;
end package;
package body attitude_math_pkg is
  function mul(a,b: fixed_t) return fixed_t is

  begin return resize(shift_right(resize(a,18)*resize(b,18),15),32); end;
  function cross(a,b: vec3_t) return vec3_t is
  begin return (mul(a(1),b(2))-mul(a(2),b(1)),mul(a(2),b(0))-mul(a(0),b(2)),mul(a(0),b(1))-mul(a(1),b(0))); end;
  function unpack(a: std_logic_vector(47 downto 0)) return vec3_t is
  begin return (resize(signed(a(47 downto 32)),32),resize(signed(a(31 downto 16)),32),resize(signed(a(15 downto 0)),32)); end;
  function extend(a: vec3_t) return vec4_t is
  begin return (a(0),a(1),a(2),to_signed(0,32)); end;
  function first3(a: vec4_t) return vec3_t is
  begin return (a(0),a(1),a(2)); end;
end package body;
