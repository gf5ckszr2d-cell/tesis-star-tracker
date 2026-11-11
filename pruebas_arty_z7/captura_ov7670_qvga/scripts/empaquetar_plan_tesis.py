"""Package the full-thesis plan while preserving the previous evidence archive."""
from pathlib import Path
import json
import zipfile

root = Path(__file__).resolve().parents[1]
out = root / 'output' / 'LAP_20261110'
build = root / 'build' / 'plan_tesis_completa_16'
previous = out / 'Documentacion_DoE_planificacion_16.zip'
target = out / 'Documentacion_DoE_tesis_completa.zip'
with zipfile.ZipFile(previous) as old:
    historical = old.read('historial/Evidencias_LAP_anteriores.zip')

plan = json.loads((build / 'plan.json').read_text(encoding='utf-8'))
assert plan['mode'] == 'PLANNING_ONLY'
assert sum(sum(r['n'] for r in plan['DoE'][d]) for d in ('D1','D2','D3','D4','D5')) == 150
assert 150 + sum(plan['DoE']['supplementary'].values()) == 207
assert 207 + plan['LAP']['new_reserved_captures'] == plan['captures_total_all'] == 407
assert plan['optional_dynamic']['total_with_extension'] == 407 + 75

readme = '''PLAN ACTUAL: TODA LA TESIS
16 diapositivas: planificación del DoE (1–11) y planificación del LAP (12–16).
Alcance: D1 captura, D2 centroide, D3 separación, D4 identificación HIP,
D5 actitud y tiempo, integración VHDL/FPGA, aceptación y entrega final de tesis.

Las matrices contienen 150 capturas propuestas. Auxiliares: 57. DoE: 207.
LAP reservado: 200. Total base: 407. Dinámica opcional: 75 (total 482).
Reintentos y registros adicionales de calibración se contabilizarán aparte.
Las cantidades y metas son propuestas previas al ensayo, no resultados obtenidos.
Las metas pendientes de cierre conservarán ese estado antes de ejecutar el LAP.

planificacion_actual/ contiene el PowerPoint, guion y fuentes del plan vigente.
historial/ conserva las evidencias anteriores sin convertirlas en conformidades
de los ensayos futuros de esta planificación. No se tomaron nuevas capturas.

Reproducción local: ejecutar crear_plan_tesis_completa.mjs con el runtime de
presentaciones configurado en ese archivo. El finalizador requiere una ruta
de salida y recibo nuevos si ya existe una revisión. Después ejecutar este
empaquetador. No requiere programar ni operar la FPGA.
'''
with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    z.writestr('LEEME_PLAN_ACTUAL.txt', readme)
    z.writestr('historial/Evidencias_LAP_anteriores.zip', historical)
    for file in [build/'plan.json', build/'slides.json',
                 root/'scripts'/'crear_plan_tesis_completa.mjs',
                 Path(__file__).resolve(),
                 out/'Guion_plan_tesis_completa_16.md',
                 out/'DoE_final_plan_tesis_completa_16_v3.pptx']:
        z.write(file, 'planificacion_actual/' + file.name)
with zipfile.ZipFile(target) as z:
    assert z.testzip() is None
print(f'OK: {target.name}, {target.stat().st_size} bytes, historical evidence preserved')
