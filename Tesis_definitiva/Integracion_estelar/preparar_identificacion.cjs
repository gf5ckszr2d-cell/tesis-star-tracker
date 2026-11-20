const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const generator = ['Generador_G5', 'Star_Tracker_FPGA/Star_Tracker_Oficial/Generadores/Generador_cielo_G5']
  .map(dir => path.join(root, dir, 'central_pattern.js')).find(file => fs.existsSync(file));
if (!generator) throw Error('Falta central_pattern.js');
const G = require(generator);
const rows = G.build().stars.map(G.project);
const center = rows.filter(r => r.inside);
const fov = 32;
const header = 'library ieee;\nuse ieee.std_logic_1164.all;\nuse ieee.numeric_std.all;\n';
const output = path.join(root, 'Tesis_definitiva/Tesis_definitiva/Tesis_definitiva.srcs/sources_1/new');
const save = (name, code) => fs.writeFileSync(path.join(output,name + '.vhd'), header + code + '\n');
const hex = (v,w) => v.toString(16).toUpperCase().padStart(w,'0');
const bits = (v,w) => v.toString(2).padStart(w,'0');
const radians = a => a*Math.PI/180;
const chord = a => 2*(1-Math.cos(radians(a)))*2**24;
const degrees = d => Math.acos(1-d/(2*2**24))*180/Math.PI;
const rays = rows.map(r => {
  const v = [r.XcameraMm,r.YcameraMm,r.ZcameraMm];
  return v.map(x=>Math.round(x/Math.hypot(...v)*32768));
});
const bounds = Array.from({length:128},(_,i)=>Math.round(chord((i+1)/4)));
const pairs = [];
for(let a=0;a<rays.length;a++) for(let b=a+1;b<rays.length;b++){
  const d=Math.floor(rays[a].reduce((s,x,j)=>s+(x-rays[b][j])**2,0)/64);
  if(d>=chord(fov)) continue;
  const bin=bounds.findIndex(v=>d<v);
  if (bin>=0) pairs.push({a,b,d,bin});
}
pairs.sort((a,b)=>a.bin-b.bin||a.d-b.d||a.a-b.a||a.b-b.b);
if(center.length!==8 || rows.length!==48 || pairs.length===0) throw Error('Patron inesperado');
const words=values=>values.map((v,i)=>'  '+i+' => '+v).join(',\n');
save('g5_star_catalog_pkg', [
  'package g5_star_catalog_pkg is',
  'constant CFG_CX_Q8 : integer := 40832;',
  'constant CFG_CY_Q8 : integer := 30592;',
  'constant CFG_SCALE_X : integer := 11623;',
  'constant CFG_SCALE_Y : integer := 11623;',
  'constant CFG_MIN_IDENTIFIED : positive := 5;',
  'constant G5_STAR_COUNT : positive := '+rays.length+';',
  'type ray_rom_t is array(0 to G5_STAR_COUNT-1) of std_logic_vector(47 downto 0);',
  'constant G5_STAR_CATALOG : ray_rom_t := (',
  words(rays.map(v=>'x"'+v.map(x=>hex(x&65535,4)).join('')+'"')),');',
  'type xy_rom_t is array(0 to 7) of std_logic_vector(33 downto 0);',
  'constant G5_CENTRAL_XY : xy_rom_t := (',
  words(center.map(r=>'"'+bits(r.xScaled256,17)+bits(r.yScaled256,17)+'"')),');',
  'end package;'
].join('\n'));
const tol=Array.from({length:129},(_,i)=> {
  const upper=(i+1)/4;
  return Math.ceil(chord(upper+0.18)-chord(upper));
});
save('g5_pair_lookup_pkg', [
  'package g5_pair_lookup_pkg is',
  'constant G5_PAIR_COUNT : positive := '+pairs.length+';',
  'type pair_rom_t is array(0 to G5_PAIR_COUNT-1) of std_logic_vector(47 downto 0);',
  'constant G5_PAIR_ROM : pair_rom_t := (',
  words(pairs.map(p=>'x"'+hex(p.a,3)+hex(p.b,3)+hex(p.d,6)+'"')),');',
  'type offsets_t is array(0 to 129) of natural range 0 to G5_PAIR_COUNT;',
  'constant G5_PAIR_OFFSET : offsets_t := (',
  words(Array.from({length:130},(_,i)=>pairs.filter(r=>r.bin<i).length)),');',
  'type bounds_t is array(0 to 127) of unsigned(23 downto 0);',
  'constant G5_BOUNDARY_CHORD : bounds_t := (',
  words(bounds.map(v=>'to_unsigned('+v+',24)')),');',
  'type tolerance_t is array(0 to 128) of unsigned(23 downto 0);',
  'constant G5_TOLERANCE_CHORD : tolerance_t := (',
  words(tol.map(v=>'to_unsigned('+v+',24)')),');','end package;'
].join('\n'));
console.log(rows.length+' referencias, '+center.length+' centrales, '+pairs.length+' pares < '+fov+' grados; mayor par: '+degrees(pairs.at(-1).d).toFixed(2));
