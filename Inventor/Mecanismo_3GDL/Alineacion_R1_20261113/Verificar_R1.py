"""Comprobación del CAD guardado, sus copias y la entrega de imágenes."""
from pathlib import Path
import hashlib
import json
import math
import re

root = Path(__file__).resolve().parent
previous = root.parent
control = root / "Control"
log = (control / "verificacion_reapertura_y_vista.txt").read_text(encoding="utf-8")
assert "REOPEN_VERIFIED=true" in log
axes = []
for line in log.splitlines():
    match = re.match(r"AXIS=(.*?) POINT_MM=([^ ]+) DIR=(.+)", line)
    if match:
        axes.append({"constraint": match[1], "point_mm": list(map(float, match[2].split(","))),
                     "direction": list(map(float, match[3].split(",")))})
assert len(axes) == 3
cross = lambda a, b: [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
dot = lambda a, b: sum(x*y for x, y in zip(a, b))
norm = lambda a: math.sqrt(dot(a, a))
center = [10.15, 114.5, 0.0]
def distance_to_axis(point, axis):
    delta = [x-y for x, y in zip(point, axis["point_mm"])]
    return norm(cross(delta, axis["direction"])) / norm(axis["direction"])
distances = [distance_to_axis(center, axis) for axis in axes]
assert max(distances) < 1e-5
orthogonality = [abs(dot(axes[i]["direction"], axes[j]["direction"])) for i, j in ((0,1),(0,2),(1,2))]
assert max(orthogonality) < 1e-10
lens_match = re.search(r"LENS_POINT_MM=([^ ]+) DIR=([^\n]+)", log)
lens_point = list(map(float, lens_match[1].split(",")))
lens_dir = list(map(float, lens_match[2].split(",")))
lens_offset = distance_to_axis(lens_point, axes[2])
assert lens_offset < 1e-5
assert norm(cross(lens_dir, axes[2]["direction"])) < 1e-10
references = re.findall(r"^REFERENCE=(.+)$", log, re.M)
assert len(references) == 9 and all(Path(p).parent == root / "CAD" for p in references)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest().upper()
original_manifest = json.loads((previous / "Revision_20261113/manifest_originales.json").read_text(encoding="utf-8-sig"))
for item in original_manifest:
    assert sha(previous / "Original" / item["relative_path"]) == item["sha256"]
untouched = []
for part in (previous / "CAD_portable").glob("*.ipt"):
    if part.name == "cajita.ipt":
        continue
    assert sha(root / "CAD" / part.name) == sha(part)
    untouched.append(part.name)
def clashes(text):
    return {tuple(sorted(pair.split(" / "))): float(volume)
            for pair, volume in re.findall(r"^INTERFERENCE=(.*?) VOLUME_MM3=([^\n]+)$", text, re.M)}
baseline = clashes((previous / "Revision_20261113/inspeccion_CAD.txt").read_text(encoding="utf-8"))
current = clashes((control / "correccion.txt").read_text(encoding="utf-8"))
assert len(current) == 23 and set(current) == set(baseline)
assert all(abs(v-baseline[k]) < 1e-6 for k, v in current.items())
images = {}
for filename in ("Captura_real_Inventor_Gimbal_R1.jpg", "Gimbal_R1_ejes_anotados_generada.png"):
    path = root / filename
    images[filename] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    signature = b"\xff\xd8" if path.suffix == ".jpg" else b"\x89PNG\r\n\x1a\n"
    assert path.read_bytes().startswith(signature)
result = {
    "saved_assembly_reopened": True, "local_direct_references": len(references),
    "tolerance_mm": 1e-5, "common_center_mm": center,
    "center_to_each_axis_mm": distances, "lens_barrel_to_roll_axis_mm": lens_offset,
    "axis_direction_dot_products_absolute": orthogonality,
    "original_16_files_preserved": True, "unchanged_copied_parts": untouched,
    "interference_pairs_count": len(current), "same_interference_pairs_as_received": True,
    "new_interference_pairs": [], "spacer_thickness_mm": .8,
    "physical_alignment_measured": False, "full_motion_sweep_verified": False,
    "images": images,
    "cad_sha256": {p.name: sha(p) for p in sorted((root / "CAD").iterdir()) if p.is_file()},
}
(control / "verificacion_R1.json").write_text(json.dumps(result, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
print(json.dumps({k:v for k,v in result.items() if k not in {"images", "cad_sha256", "unchanged_copied_parts"}}, indent=2))
