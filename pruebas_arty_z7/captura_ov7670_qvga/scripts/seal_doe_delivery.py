"""Seal source/artifact identity after Vivado and Vitis complete; never programs a board."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(root/'scripts/verify_delivery.py')],check=True)
for file,marker in [('banco_doe_build.log','PASS_BUILD_DIAGNOSTICO'),
                    ('banco_doe_vitis.log','PASS_VITIS_INDEPENDIENTE'),
                    ('banco_doe_runtime_test.log','PASS_SCCB_RUNTIME'),
                    ('banco_doe_top_runtime_test.log','PASS_TOP_RUNTIME'),
                    ('banco_doe_sccb_test.log','PASS_SCCB_TIMING'),
                    ('banco_doe_python_tests.log','OK')]:
    if marker not in (root/'build'/file).read_text(encoding='utf-8',errors='replace'):
        raise RuntimeError(f'Missing {marker} in {file}')
out=root/'build/diagnostico/resultados'
browser=json.loads((root/'build/banco_doe_browser_test.json').read_text(encoding='utf-8'))
if browser['result']!='PASS_BROWSER_DOE' or browser['javascript_errors']:
    raise RuntimeError('Browser QA is incomplete')
if b'ARM DOE1 READY' not in (out/'receptor_ov7670_test.elf').read_bytes():
    raise RuntimeError('ARM ELF has no DOE1 firmware signature')
paths=list((root/'rtl').glob('*.vhd'))+list((root/'arm/src').glob('*.c'))
paths+=list((root/'constraints').glob('*.xdc'))
paths+=[p for p in (root/'scripts').iterdir() if p.suffix in ('.tcl','.py','.ps1','.cjs')]
paths+=list((root/'pc').glob('*.py'))+list((root/'pc').glob('requirements*.txt'))+list((root/'pc/doe_web').glob('*.html'))
paths+=[out/name for name in ('sistema_captura_arm_wrapper.bit','sistema_captura_arm_wrapper.xsa','receptor_ov7670_test.elf','ps7_init.tcl')]
report=dict(version='DOE1',physical_capture_verified=False,
            sha256={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths})
(out/'doe_release.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(root/'build/banco_environment.json').write_text(json.dumps({'python_executable':sys.executable},indent=2),encoding='utf-8')
print('PASS_DOE_RELEASE: matching RTL/ARM/BIT/XSA/ELF; physical verification pending')
