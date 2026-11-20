const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const [out, phase] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });

function draw(file, title, diagram) {
  const edges = diagram.trim().split('\n').map(line => {
    const [source, target, label] = line.trim().split('|');
    return `${source} -> ${target}${label ? ' [label=' + JSON.stringify(label) + ']' : ''};`;
  });
  const dot = path.join(out, file + '.dot');
  fs.writeFileSync(dot, [
    'digraph {',
    'graph [rankdir=TB, labelloc=t, label=' + JSON.stringify(title) + ', fontname=Arial, fontsize=22, pad=0.28];',
    'node [shape=circle, style=filled, fillcolor="#EAF1F8", color="#516579", fontname=Arial, fontsize=10];',
    'edge [fontname=Arial, color="#40566C", fontsize=10];',
    ...edges, '}',
  ].join('\n'));
  execFileSync('dot', ['-Tpng', '-Gdpi=144', dot, '-o', path.join(out, file + '.png')]);
}

if (phase === 'carga') {
  draw('01a_carga', 'Identificación estelar · carga registrada', `
    IDLE|IDLE|sin flanco de list_ready
    IDLE|FINISH|flanco de list_ready y lista vacía o desbordada
    IDLE|LOAD_REQ|flanco de list_ready y lista disponible
    LOAD_REQ|LOAD_WAIT|/ rd_index
    LOAD_WAIT|LOAD_TAKE
    LOAD_TAKE|LOAD_NEXT|rd_valid = 0
    LOAD_TAKE|LOAD_INSERT|rd_valid = 1 y lista selecta vacía
    LOAD_TAKE|LOAD_RANK|rd_valid = 1 y lista selecta con datos
    LOAD_RANK|LOAD_COMPARE
    LOAD_COMPARE|LOAD_INSERT|mayor intensidad o último puesto libre
    LOAD_COMPARE|LOAD_NEXT|lista llena e intensidad insuficiente
    LOAD_COMPARE|LOAD_RANK|siguiente puesto
    LOAD_INSERT|LOAD_NEXT
    LOAD_NEXT|LOAD_REQ|quedan centroides
    LOAD_NEXT|FINISH|último centroide y muestra insuficiente
    LOAD_NEXT|PREP_DIFF|último centroide y muestra suficiente
    FINISH|IDLE|/ done
  `);
} else if (phase !== 'actitud') {
  draw('01a_carga', 'Identificación estelar · carga de centroides', `
    IDLE|IDLE|sin flanco de list_ready
    IDLE|FINISH|flanco de list_ready y lista vacía o desbordada
    IDLE|LOAD_REQ|flanco de list_ready y lista disponible
    LOAD_REQ|LOAD_WAIT|/ rd_index
    LOAD_WAIT|LOAD_TAKE
    LOAD_TAKE|LOAD_REQ|quedan centroides
    LOAD_TAKE|FINISH|último centroide y muestra insuficiente
    LOAD_TAKE|PREP_DIFF|último centroide y muestra suficiente
    FINISH|IDLE|/ done
  `);
  draw('01b_rayos', 'Identificación estelar · cálculo de rayos', `
    PREP_DIFF|PREP_SCALE
    PREP_SCALE|PREP_SQUARE
    PREP_SQUARE|PREP_RADIUS_SUM
    PREP_RADIUS_SUM|PREP_RADIUS
    PREP_RADIUS|FINISH|índice de radio > 511
    PREP_RADIUS|PREP_NORM|índice de radio ≤ 511
    PREP_NORM|PREP_PRODUCT
    PREP_PRODUCT|PREP_ROUND
    PREP_ROUND|PREP_FINAL
    PREP_FINAL|PREP_DIFF|queda otro centroide
    PREP_FINAL|PREP_PAIR_READ|último centroide
  `);
  draw('01c_pares', 'Identificación estelar · pares observados', `
    PREP_PAIR_READ|PREP_PAIR
    PREP_PAIR|PREP_PAIR_SQUARE
    PREP_PAIR_SQUARE|PREP_PAIR_SUM
    PREP_PAIR_SUM|PREP_BIN_INIT
    PREP_BIN_INIT|PREP_BIN_LOOKUP
    PREP_BIN_LOOKUP|PREP_BIN_COMPARE
    PREP_BIN_COMPARE|PREP_BIN_LOOKUP|bin_step < 7
    PREP_BIN_COMPARE|PREP_BIN_STORE|bin_step = 7
    PREP_BIN_STORE|PREP_PAIR_READ|queda otro par
    PREP_BIN_STORE|ANCHOR_START|último par
  `);
  draw('01d_hipotesis', 'Identificación estelar · búsqueda y emisión', `
    ANCHOR_START|PAIR_FETCH
    PAIR_FETCH|PAIR_CHECK|quedan parejas
    PAIR_FETCH|EMIT|parejas agotadas / success si hay ≥ 5 coincidencias
    PAIR_CHECK|PAIR_DECIDE
    PAIR_DECIDE|HYP_START|pareja compatible
    PAIR_DECIDE|PAIR_NEXT|pareja incompatible
    HYP_START|HYP_STAR
    HYP_STAR|HYP_STAR|centroide de anclaje
    HYP_STAR|CAND_START|centroide sin asignar
    CAND_START|HYP_STAR|candidatos agotados
    HYP_STAR|HYP_SCORE|centroides agotados
    HYP_SCORE|HYP_START|falta probar orientación inversa
    HYP_SCORE|PAIR_NEXT|ambas orientaciones evaluadas
    PAIR_NEXT|PAIR_FETCH
    EMIT|EMIT|índice con coincidencia / match_valid, índices, rayo
    EMIT|EMIT|índice sin coincidencia
    EMIT|FINISH|índices agotados
    FINISH|IDLE|/ done
  `);
  draw('01e_candidatos', 'Identificación estelar · evaluación de candidatos', `
    HYP_STAR|CAND_START|centroide sin asignar
    CAND_START|HYP_STAR|candidatos agotados
    CAND_START|CAND_START|ID ya asignado
    CAND_START|CAND_FETCH|ID libre
    CAND_FETCH|CAND_START|chequeos agotados
    CAND_FETCH|CAND_FETCH|centroide sin asignación previa
    CAND_FETCH|CAND_CHECK|centroide con asignación previa
    CAND_CHECK|CAND_SQUARE
    CAND_SQUARE|CAND_SUM
    CAND_SUM|CAND_DIFF
    CAND_DIFF|CAND_TOLERANCE
    CAND_TOLERANCE|CAND_DECIDE
    CAND_DECIDE|CAND_START|diferencia > tolerancia
    CAND_DECIDE|CAND_FETCH|diferencia ≤ tolerancia
  `);
} else {
  draw('01a_seleccion', 'TRIAD · selección de la pareja', `
    IDLE|IDLE|match_valid = 1 y count < 8 / guardar pareja de rayos
    IDLE|FINISH|solve = 1 y resultado insuficiente
    IDLE|PAIR_SCAN|solve = 1 y count ≥ 5 e identification_ok = 1
    PAIR_SCAN|CROSS_MUL
    CROSS_MUL|CROSS_SUB
    CROSS_SUB|PAIR_SQUARE|cross_to_norm = 0
    PAIR_SQUARE|PAIR_SUM
    PAIR_SUM|PAIR_DECIDE
    PAIR_DECIDE|PAIR_SCAN|queda otra pareja
    PAIR_DECIDE|NORM_START|última pareja
  `);
  draw('01b_cuaternion', 'TRIAD · bases y cuaternión', `
    NORM_START|FINISH|best < 1000000
    NORM_START|CROSS_MUL|fase 2 o 3
    CROSS_MUL|CROSS_SUB
    CROSS_SUB|NORM_WAIT|cross_to_norm = 1 / norm_start_s
    NORM_START|NORM_WAIT|fase 0, 1 o 4 / norm_start_s
    NORM_WAIT|NORM_WAIT|norm_done = 0
    NORM_WAIT|FINISH|norm_done = 1 y norm_valid = 0
    NORM_WAIT|NORM_START|norm_done y norm_valid y fase < 3
    NORM_WAIT|MATRIX_BUILD|norm_done y norm_valid y fase 3
    MATRIX_BUILD|MATRIX_SUM
    MATRIX_SUM|MATRIX_BUILD|queda otra celda
    MATRIX_SUM|QUAT_TRACE|última celda
    QUAT_TRACE|QUAT_CANDIDATES
    QUAT_CANDIDATES|QUAT_SELECT
    QUAT_SELECT|QUAT_BUILD
    QUAT_BUILD|NORM_START|fase = 4
    NORM_WAIT|CHECK_RESIDUAL|norm_done y norm_valid y fase 4
  `);
  draw('01c_residuos', 'TRIAD · verificación de residuos', `
    CHECK_RESIDUAL|RES_SUM
    RES_SUM|RES_DIFF
    RES_DIFF|RES_SQUARE
    RES_SQUARE|RES_TOTAL
    RES_TOTAL|RES_DECIDE
    RES_DECIDE|CHECK_RESIDUAL|queda otro rayo
    RES_DECIDE|FINISH|último rayo
    FINISH|IDLE|/ done, valid, quaternion
  `);
  draw('02a_normalizar', 'Máquina de estados de normalización', `
    IDLE|SUMSQ|start = 1
    SUMSQ|SUM_ADD
    SUM_ADD|SUM_ADD|queda otro cuadrado
    SUM_ADD|ROOT_TRIAL
    ROOT_TRIAL|ROOT_SQUARE
    ROOT_SQUARE|ROOT_STEP
    ROOT_STEP|ROOT_TRIAL|queda bit de raíz
    ROOT_STEP|DIV_START|último bit de raíz
    DIV_START|FINISH|denominador fuera de rango
    DIV_START|DIV_WAIT|denominador válido / div_start
    DIV_WAIT|DIV_WAIT|div_done = 0
    DIV_WAIT|DIV_START|div_done = 1 y queda componente
    DIV_WAIT|FINISH|div_done = 1 y última componente
    FINISH|IDLE|/ done
  `);
  draw('05_top', 'Máquina de estados del flujo integrado', `
    ESPERAR_RESULTADO|IDENTIFICAR|resultado_listo = 1 / comenzar_foto
    IDENTIFICAR|RESOLVER_ACTITUD|fin_id = 1
    RESOLVER_ACTITUD|ENVIAR_IMAGEN|fin_actitud = 1 / enviar_foto
    ENVIAR_IMAGEN|ENVIAR_CENTROIDES|fin_foto = 1 / inicio_lista
    ENVIAR_CENTROIDES|ENVIAR_MATCHES|fin_lista = 1 / inicio_matches
    ENVIAR_MATCHES|ENVIAR_ACTITUD|fin_uart_matches = 1 / inicio_actitud_uart
    ENVIAR_ACTITUD|ESPERAR_RESULTADO|fin_actitud_uart = 1 / liberar_imagen
  `);
}
