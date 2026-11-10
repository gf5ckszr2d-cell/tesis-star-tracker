"""Verify independent source/project/artifact ownership; does not program board."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
config=json.loads((root/'variante.json').read_text())
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
out=root/'build/diagnostico/resultados'
workspace=root/'vitis'
with zipfile.ZipFile(out/'sistema_captura_arm_wrapper.xsa') as z:
    bits=[n for n in z.namelist() if n.endswith('.bit')]
    assert len(bits)==1 and hashlib.sha256(z.read(bits[0])).hexdigest()==sha(out/'sistema_captura_arm_wrapper.bit')
assert (root/'build/proyecto'/(root.name+'.xpr')).is_file()
for row in (root/'build/fuentes_proyecto.txt').read_text().splitlines():
    raw=row.split('\t',1)[1].replace('Q:/','C:/Users/alexa/tesis-star-tracker/')
    p=Path(raw).resolve()
    assert p.is_relative_to(root.resolve()),p
app=workspace/'receptor_ov7670_test'
for source in (root/'arm/src').iterdir():
    if source.is_file(): assert sha(source)==sha(app/'src'/source.name),source
assert sha(out/'receptor_ov7670_test.elf')==sha(app/'build/receptor_ov7670_test.elf')
assert sha(out/'sistema_captura_arm_wrapper.xsa')==sha(workspace/'plataforma_ov7670/hw/sistema_captura_arm_wrapper.xsa')
assert sha(out/'ps7_init.tcl')==sha(workspace/'plataforma_ov7670/hw/sdt/ps7_init.tcl')
assert sha(out/'sistema_captura_arm_wrapper.bit')==sha(app/'_ide/bitstream/sistema_captura_arm_wrapper.bit')
report={'project':root.name,'resolution':config['resolution'],'independent_project_and_workspace':True,
        'artifacts_sha256':{p.name:sha(p) for p in out.iterdir() if p.suffix in ('.bit','.xsa','.elf','.tcl')}}
(root/'build/verificacion_independencia.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS_VARIANTE_INDEPENDIENTE: '+root.name+' '+str(config['resolution']))
