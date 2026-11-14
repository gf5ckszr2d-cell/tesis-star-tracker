"""Resume evidencia ya calculada; no vuelve a accionar Inventor."""
import csv
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parent
control = root / "Control"
def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))
poses = read_csv(control / "poses.csv")
grid = read_csv(control / "Barrido125/poses.csv")
assert len(poses) == 22 and len(grid) == 125
assert all(r["status"] == "ok" for r in poses + grid)
assert "AUDIT_COMPLETE=true" in (control / "Barrido125/auditoria.txt").read_text(encoding="utf-8")
clashes = read_csv(control / "Barrido125/interferencias_movimiento.csv")
def received_hub_pair(row):
    a, b = row["component_a"], row["component_b"]
    names = {a.split(":")[0], b.split(":")[0]}
    return names == {"Servo MG996R", "Pieza6"} and a.split(":")[-1] == b.split(":")[-1]
other = [r for r in clashes if not received_hub_pair(r) and float(r["volume_mm3"]) > .001]
bad_poses = sorted({r["pose"] for r in other})
central = [r for r in grid if max(abs(float(r[k])) for k in ("yaw_command_deg", "pitch_command_deg", "roll_command_deg")) <= 30]
assert len(central) == 27 and not any(r["pose"] in bad_poses for r in central)
max_center = max(float(r["O_displacement_mm"]) for r in grid)
max_axis = max(float(r["max_axis_miss_mm"]) for r in grid)
assert max_center < 1e-5 and max_axis < 1e-5
live_axis_log = (control / "ejes_moviles_verificados.txt").read_text(encoding="utf-8")
assert "LIVE_AXIS_BINDING_PASS=true" in live_axis_log
r1 = root.parent / "Alineacion_R1_20261113"
original_hashes = json.loads((r1 / "Control/verificacion_R1.json").read_text(encoding="utf-8"))["cad_sha256"]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper()
for name, digest in original_hashes.items():
    assert sha(r1 / "CAD" / name) == digest
for part in (root / "CAD").glob("*.ipt"):
    if part.name not in {"Referencias_cinematicas.ipt", "Servo MG996R.ipt"}:
        assert sha(part) == sha(r1 / "CAD" / part.name)
by_name = {r["pose"]: r for r in poses}
selected = {name: {k: float(by_name[name][k]) for k in ("P_displacement_mm", "S_displacement_mm", "O_displacement_mm")}
            for name in ("yaw_30", "pitch_30", "roll_30", "combined_30")}
assert abs(selected["yaw_30"]["P_displacement_mm"] - 2*8.36551218215*math.sin(math.pi/12)) < 1e-8
summary = {
    "audit_completed": "2026-11-14", "native_pose_samples": 22,
    "grid_samples": 125, "solver_failures": 0,
    "max_mechanical_center_displacement_mm": max_center,
    "max_center_to_rotational_axis_distance_mm": max_axis,
    "barrel_point_offset_from_center_mm": 8.36551218215,
    "selected_point_displacements": selected,
    "poses_with_other_body_collisions": len(bad_poses),
    "other_collision_pairs": [list(p) for p in sorted({tuple(sorted((r["component_a"], r["component_b"]))) for r in other})],
    "body_collision_pose_names": bad_poses,
    "central_27_samples_no_other_body_collision": True,
    "hub_contact_exclusion": "Only Servo MG996R:i with Pieza6:i; user reports smaller physical shaft; dimensions unmeasured",
    "servo_shaft_model_diameter_mm": 2*3.59201549707,
    "pieza6_nominal_central_bore_diameter_mm": 5.5,
    "physical_entrance_pupil_located": False,
    "physical_servo_dimensions_measured": False,
    "mechanical_parts_modified_by_audit": False,
    "servo_copy_added_construction_axis_only": True,
    "live_axes_bound_to_shaft_cylinders_verified_after_rotation": True,
    "R1_all_saved_CAD_hashes_preserved": True,
    "bolts_wires_and_continuous_sweep_in_grid_collision_check": False,
}
(control / "resumen_verificado.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")

# Figura vectorial nueva, construida con los puntos exportados por Inventor.
origin = (290, 335)
scale = 20
def point(row):
    return origin[0]+(float(row["P_x_mm"])-10.15)*scale, origin[1]-float(row["P_z_mm"])*scale
path_rows = sorted([r for r in poses if r["pose"].startswith("yaw_")] + [by_name["zero"]], key=lambda r: float(r["yaw_command_deg"]))
path = " ".join(f"{x:.2f},{y:.2f}" for x,y in map(point,path_rows))
x0,y0 = point(by_name["zero"])
x30,y30 = point(by_name["yaw_30"])
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="470" viewBox="0 0 1100 470">
<rect width="1100" height="470" fill="#ffffff"/>
<g font-family="Arial, sans-serif" fill="#162434">
<text x="40" y="37" font-size="23">Centro mecánico y punto del barril: referencias distintas</text>
<text x="40" y="69" font-size="15">Geometría R1 exportada de Inventor. La pupila de entrada real aún no está medida.</text>
<text x="40" y="113" font-size="18">Giro yaw: vista del plano XZ</text>
<line x1="80" y1="335" x2="490" y2="335" stroke="#abb7c5"/>
<line x1="290" y1="140" x2="290" y2="365" stroke="#abb7c5"/>
<polyline points="{path}" stroke="#d66c16" stroke-width="3" fill="none"/>
<line x1="290" y1="335" x2="{x0}" y2="{y0}" stroke="#2571b9" stroke-width="2"/>
<line x1="290" y1="335" x2="{x30}" y2="{y30}" stroke="#2571b9" stroke-width="2" stroke-dasharray="5 5"/>
<line x1="{x0}" y1="{y0}" x2="{x30}" y2="{y30}" stroke="#b73445" stroke-width="2"/>
<circle cx="290" cy="335" r="6" fill="#1a7d52"/>
<circle cx="{x0}" cy="{y0}" r="5" fill="#2571b9"/>
<circle cx="{x30}" cy="{y30}" r="5" fill="#d66c16"/>
<text x="300" y="360" font-size="16">O fijo</text>
<text x="300" y="163" font-size="16">P a 0°</text>
<text x="110" y="201" font-size="16">P a 30°</text>
<text x="151" y="148" font-size="15" fill="#b73445">Desplazamiento: 4,330 mm</text>
<text x="320" y="265" font-size="15">OP = 8,366 mm</text>
<text x="40" y="410" font-size="15">O permanece fijo. P describe un arco porque está separado de O.</text>
<text x="580" y="113" font-size="18">Posición inicial sobre el eje óptico modelado</text>
<line x1="590" y1="250" x2="1040" y2="250" stroke="#2571b9" stroke-width="2"/>
<line x1="645" y1="210" x2="645" y2="290" stroke="#7e8997" stroke-width="3"/>
<circle cx="690" cy="250" r="6" fill="#1a7d52"/>
<circle cx="940" cy="250" r="6" fill="#2571b9"/>
<text x="596" y="196" font-size="15">Plano PCB S</text>
<text x="600" y="315" font-size="15">−1,5 mm</text>
<text x="678" y="221" font-size="17">O</text>
<text x="678" y="315" font-size="15">0</text>
<text x="931" y="221" font-size="17">P</text>
<text x="902" y="315" font-size="15">+8,366 mm</text>
<text x="580" y="361" font-size="15">P es un punto geométrico del barril, no la pupila medida.</text>
<text x="580" y="390" font-size="15">S es una referencia de PCB, no una localización del sensor.</text>
<text x="580" y="419" font-size="15">La referencia óptica E se debe localizar físicamente.</text>
</g></svg>'''
(root / "Centro_mecanico_y_punto_del_barril.svg").write_text(svg, encoding="utf-8")
print(json.dumps({k:v for k,v in summary.items() if k not in {"body_collision_pose_names", "selected_point_displacements"}}, indent=2))
