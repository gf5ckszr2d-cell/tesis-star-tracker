"""Create/update this variant's own Vitis workspace. No board programming."""
from pathlib import Path
import shutil
import json
import vitis
root=Path(__file__).resolve().parents[1]
import subprocess
repo=root.parents[1]
short_repo=Path('Q:/')
if not short_repo.exists(): subprocess.run(['subst','Q:',str(repo)],check=True)
if not short_repo.samefile(repo): raise RuntimeError('Q: points outside this repository')
workspace=short_repo/'pruebas_arty_z7'/root.name/'vitis'
out=root/'build/diagnostico/resultados'
client=vitis.create_client()
try:
    client.set_workspace(path=str(workspace))
    if (workspace/'plataforma_ov7670/vitis-comp.json').is_file():
        platform=client.get_component(name='plataforma_ov7670')
        platform.update_hw(hw_design=str(out/'sistema_captura_arm_wrapper.xsa'))
    else:
        platform=client.create_platform_component(name='plataforma_ov7670',
            hw_design=str(out/'sistema_captura_arm_wrapper.xsa'),os='standalone',
            cpu='ps7_cortexa9_0',domain_name='standalone_ps7_cortexa9_0')
    platform.build()
    appdir=workspace/'receptor_ov7670_test'
    if (appdir/'vitis-comp.json').is_file():
        app=client.get_component(name='receptor_ov7670_test')
    else:
        xpfm=workspace/'plataforma_ov7670/export/plataforma_ov7670/plataforma_ov7670.xpfm'
        assert xpfm.is_file(),xpfm
        app=client.create_app_component(name='receptor_ov7670_test',platform=str(xpfm),
            domain='standalone_ps7_cortexa9_0',template='empty_application')
    shutil.copytree(root/'arm/src',appdir/'src',dirs_exist_ok=True)
    app.build()
    shutil.copy2(appdir/'build/receptor_ov7670_test.elf',out/'receptor_ov7670_test.elf')
    psinit=workspace/'plataforma_ov7670/hw/sdt/ps7_init.tcl'
    shutil.copy2(psinit,out/'ps7_init.tcl')
    (appdir/'_ide/psinit').mkdir(parents=True,exist_ok=True)
    (appdir/'_ide/bitstream').mkdir(parents=True,exist_ok=True)
    shutil.copy2(psinit,appdir/'_ide/psinit/ps7_init.tcl')
    shutil.copy2(out/'sistema_captura_arm_wrapper.bit',appdir/'_ide/bitstream/sistema_captura_arm_wrapper.bit')
    shutil.copy2(root/'arm/launch.json',appdir/'_ide/launch.json')
    print('PASS_VITIS_INDEPENDIENTE: '+str(workspace))
finally:
    vitis.dispose()
