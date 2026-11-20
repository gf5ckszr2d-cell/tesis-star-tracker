const fs = require('node:fs');
const cp = require('node:child_process');
const path = require('node:path');
const out = path.resolve(process.argv[2]);
fs.mkdirSync(out,{recursive:true});
function graph(file,title,body,dir='LR') {
  const dot = 'digraph { graph [rankdir='+dir+', label='+JSON.stringify(title)+', labelloc=t, fontname="Arial", fontsize=23, pad=0.25, nodesep=0.30, ranksep=0.50];\n'
    +'node [shape=box, style="rounded,filled", fillcolor="#EAF1F8", color="#516579", fontname="Arial", fontsize=13];\n'
    +'edge [fontname="Arial", fontsize=10, color="#40566C"];\n'+body.trimEnd()+'\n}\n';
  const source=path.join(out,file+'.dot');
  fs.writeFileSync(source,dot);
  cp.execFileSync('dot',['-Tpng','-Gdpi=144',source,'-o',path.join(out,file+'.png')]);
}
if (process.argv[3]==='actitud') {
  graph('06_operaciones','Flujo de la aritmética de punto fijo',`
    R [label="Rayo de 48 bits"]; C [label="Separar X, Y y Z"]; S [label="Extender signo a 32 bits"];
    R -> C -> S;
    A [label="Dos componentes"]; M [label="Multiplicar a 18 bits por operando"];
    D [label="Desplazar 15 bits"]; F [label="Producto en escala 32768"];
    A -> M -> D -> F;
    V [label="Dos vectores"]; P [label="Productos entre componentes"];
    X [label="Restar los productos correspondientes"]; O [label="Producto cruzado"];
    V -> P -> X -> O;
  `);
  graph('00_flujo','Determinación de actitud',`M [label="Coincidencias + rayos"]; A [label="TRIAD"]; Q [label="Cuaternión w, x, y, z"]; U [label="UART STQ2"]; M -> A -> Q -> U; R [label="ROM: 48 rayos"]; R -> A; N [label="Normalización + división"]; A -> N; N -> A;`);
  graph('03_dividir','Flujo de la división secuencial',`A [label="Cargar numerador y denominador"]; B [label="Desplazar resto y recibir siguiente bit"]; C [label="¿Resto ≥ denominador?",shape=diamond]; D [label="Restar denominador y marcar bit"]; E [label="¿Último bit?",shape=diamond]; F [label="Entregar cociente"]; A -> B -> C; C -> D [label="sí"]; C -> E [label="no"]; D -> E; E -> B [label="no"]; E -> F [label="sí"]; `,'TB');
  graph('04_uart','Máquina de estados del envío STQ2',`node [shape=circle, fontsize=10]; I [label="Reposo"]; P [label="Preparar\nbyte"]; E [label="Enviar"]; W [label="Esperar"]; I -> P [label="iniciar = 1"]; P -> E; E -> E [label="uart_busy = 1"]; E -> W [label="uart_busy = 0 / uart_start"]; W -> P [label="uart_done y quedan bytes"]; W -> I [label="uart_done y último byte / fin"]; `);
} else {
  graph('00_flujo','Identificación estelar por pares',`A [label="Lista de centroides"]; B [label="Controlador de identificación"]; C [label="Índice observado y referencia"]; U [label="UART STM1"]; A -> B -> C -> U; L [label="Tabla inversa de raíz"]; R [label="ROM de rayos"]; P [label="ROM de parejas"]; L -> B; R -> B; P -> B;`);
  graph('02_normalizacion','Flujo de la tabla inversa de raíz',`A [label="Radio tangente al cuadrado"]; B [label="Índice de 0 a 511"]; C [label="G5_INV_SQRT"]; D [label="Factor de normalización"]; A -> B -> C -> D;`);
  graph('03_estrellas','Flujo de la ROM de estrellas',`A [label="Índice de referencia"]; B [label="G5_STAR_CATALOG"]; C [label="Dirección XYZ en Q1.15"]; A -> B -> C; D [label="Índice P01 a P08"]; E [label="G5_CENTRAL_XY"]; F [label="XY nominal de cámara"]; D -> E -> F;`);
  graph('04_pares','Flujo de la ROM de parejas',`A [label="Cuerda observada"]; B [label="Buscar intervalo de 0,25°"]; C [label="Leer rango de direcciones"]; D [label="Leer los dos ID y la cuerda"]; E [label="Comparar con tolerancia"]; A -> B -> C -> D -> E;`);
  graph('05_uart','Máquina de estados del envío STM1',`node [shape=circle, fontsize=10]; I [label="Reposo"]; P [label="Preparar\nbyte"]; E [label="Enviar"]; W [label="Esperar"]; I -> I [label="match_valido = 1 / guardar par"]; I -> P [label="iniciar = 1"]; P -> E; E -> E [label="uart_busy = 1"]; E -> W [label="uart_busy = 0 / uart_start"]; W -> P [label="uart_done y quedan bytes"]; W -> I [label="uart_done y último byte / fin"]; `);
}
