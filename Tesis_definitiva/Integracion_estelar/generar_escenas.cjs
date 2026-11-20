const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const file = ['Generador_G5','Star_Tracker_FPGA/Star_Tracker_Oficial/Generadores/Generador_cielo_G5']
  .map(dir=>path.join(root,dir,'central_pattern.js')).find(p=>fs.existsSync(p));
const G = require(file);
const pattern = G.build().stars.map(G.project);
function scene(yaw,roll,pitch) {
  const a=yaw*Math.PI/180, b=roll*Math.PI/180, c=pitch*Math.PI/180;
  const result=[];
  for(const p of pattern){
    const x=Math.cos(a)*p.XcameraMm-Math.sin(a)*p.ZcameraMm;
    const depth=Math.sin(a)*p.XcameraMm+Math.cos(a)*p.ZcameraMm;
    const y=Math.cos(c)*p.YcameraMm-Math.sin(c)*depth;
    const z=Math.sin(c)*p.YcameraMm+Math.cos(c)*depth;
    if(z<=0) continue;
    const u=G.cx+G.fx*(Math.cos(b)*x+Math.sin(b)*y)/z;
    const v=G.cy+G.fx*(-Math.sin(b)*x+Math.cos(b)*y)/z;
    if(u>=3&&u<=316&&v>=3&&v<=236) result.push([Math.round(u*256),Math.round(v*256),Number(p.id.slice(1))-1]);
  }
  return result.reverse();
}
const angles = [[0,0,0],[0,9,0],[4,-5,0],[-48,0,-15],[41,0,-24],[-8,0,0],[-14,0,0],[-4,-10,-1]];
const scenes = angles.map(args=>scene(...args));
if(scenes[0].length!==8 || scenes.some(s=>s.length<5||s.length>8)) throw Error('Escenas de prueba inesperadas');
const out=path.resolve(process.argv[2]);
fs.mkdirSync(out,{recursive:true});
const stage=scenes.map(s=>'('+Array.from({length:8},(_,i)=>'('+((s[i]||[0,0,0]).join(','))+')').join(',')+')').join(',\n');
function quaternion(yaw,roll,pitch) {
  const a=yaw*Math.PI/360, b=roll*Math.PI/360, c=-pitch*Math.PI/360;
  const [sy,sr,sp]=[a,b,c].map(Math.sin);
  const [cy,cr,cp]=[a,b,c].map(Math.cos);
  return [
    cy*cp*cr + sy*sp*sr,
    cy*sp*cr + sy*cp*sr,
    sy*cp*cr - cy*sp*sr,
    cy*cp*sr - sy*sp*cr,
  ].map(component=>Math.round(component*32768));
}
const expected=angles.map(args=>'('+quaternion(...args).join(',')+')').join(',\n');
fs.writeFileSync(path.join(out,'escenas_pkg.vhd'),`package escenas_pkg is
type punto_t is array(0 to 2) of natural;
type escena_t is array(0 to 7) of punto_t;
type escenas_t is array(0 to ${scenes.length-1}) of escena_t;
type cantidades_t is array(0 to ${scenes.length-1}) of natural;
type cuaternion_t is array(0 to 3) of integer;
type cuaterniones_t is array(0 to ${scenes.length-1}) of cuaternion_t;
constant escenas : escenas_t := (${stage});
constant cantidades : cantidades_t := (${scenes.map(s=>s.length).join(',')});
constant cuaterniones : cuaterniones_t := (${expected});
end package;
`);
const histogram=Array.from({length:pattern.length+1},()=>0);
const grid=Array.from({length:69},(_,row)=>Array.from({length:99},(_,col)=>{
  const observed=scene(col-49,0,row-34).length;
  histogram[observed]++;
  return observed;
}));
fs.writeFileSync(path.join(out,'cobertura.json'),JSON.stringify({
  modelo: 'Proyección ideal del patrón G5, margen de 3 px',
  yaw: [-49,49],
  pitch: [-34,34],
  paso: 1,
  roll: 0,
  histograma: histogram.slice(0,histogram.findLastIndex(n=>n>0)+1),
  grilla: grid,
  escenas: angles.map(([yaw,roll,pitch],index)=>({
    yaw,roll,pitch,ids:scenes[index].map(p=>p[2]+1),q:quaternion(yaw,roll,pitch),
  })),
},null,2)+'\n');
for(let index=0;index<scenes.length;index++) console.log(angles[index].join(','),scenes[index].map(p=>p[2]+1).join(','));
