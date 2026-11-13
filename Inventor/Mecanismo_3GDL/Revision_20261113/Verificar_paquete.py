"""Verifica copias y resume la evidencia CAD; no modifica modelos."""
from pathlib import Path
import hashlib
import json
import math
import re

root = Path(__file__).resolve().parent.parent
review = root / "Revision_20261113"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper()
originals = json.loads((review / "manifest_originales.json").read_text(encoding="utf-8-sig"))
dependencies = json.loads((review / "manifest_dependencias.json").read_text(encoding="utf-8-sig"))
for item in originals:
    path = root / "Original" / item["relative_path"]
    assert path.stat().st_size == item["bytes"]
    assert sha(path) == item["sha256"]
    if path.parent == root / "Original" and path.suffix in {".ipt", ".iam", ".ipn"}:
        assert sha(root / "CAD_portable" / path.name) == item["sha256"]
for item in dependencies:
    path = root / item["relative_path"]
    assert path.stat().st_size == item["bytes"]
    assert sha(path) == item["sha256"]
log = (review / "inspeccion_CAD.txt").read_text(encoding="utf-8")
refs = re.findall(r"^REFERENCE=(.*?) MISSING=(\w+)$", log, re.M)
assert len(refs) == 8 and all(missing == "False" for _, missing in refs)
assert all(Path(path).parent == root / "CAD_portable" for path, _ in refs)
interferences = [
    {"pair": pair, "volume_mm3": float(volume)}
    for pair, volume in re.findall(r"^INTERFERENCE=(.*?) VOLUME_MM3=([^\n]+)$", log, re.M)
]
axes = []
for name in ("Coincidencia:36", "Coincidencia:38", "Coincidencia:40"):
    line = next(line for line in log.splitlines() if line.startswith("CONSTRAINT=" + name + " "))
    match = re.search(r" AXIS=([^ ]+) DIR=([^ ]+)", line)
    axes.append({"constraint": name, "point_mm": list(map(float, match[1].split(","))),
                 "direction": list(map(float, match[2].split(",")))})
cross = lambda a, b: [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
dot = lambda a, b: sum(x*y for x, y in zip(a, b))
distances = []
for i, j in ((0, 1), (0, 2), (1, 2)):
    normal = cross(axes[i]["direction"], axes[j]["direction"])
    delta = [b-a for a, b in zip(axes[i]["point_mm"], axes[j]["point_mm"])]
    distance = abs(dot(delta, normal)) / math.sqrt(dot(normal, normal))
    distances.append({"axes": [i+1, j+1], "shortest_distance_mm": distance})
result = {
    "original_files_verified": len(originals),
    "dependency_files_verified": len(dependencies),
    "portable_cad_files": len(list((root / "CAD_portable").glob("*.*"))),
    "resolved_assembly_references": len(refs),
    "assembly_occurrences": 39,
    "assembly_constraints": 88,
    "interferences_at_saved_pose": interferences,
    "actuator_axes": axes,
    "axis_pair_distances": distances,
    "cad_saved_by_inspection": False,
    "physical_validation": False,
    "motion_sweep_performed": False,
}
axes_log = (review / "revision_ejes.txt").read_text(encoding="utf-8")
match = re.search(r"CAMERA_CYLINDER_RADIUS_MM=7 CENTER_MM=([^ ]+) AXIS=([^\n]+)", axes_log)
camera_point = list(map(float, match[1].split(",")))
camera_axis = list(map(float, match[2].split(",")))
roll_axis = axes[2]
delta = [b-a for a, b in zip(roll_axis["point_mm"], camera_point)]
cross_delta = cross(delta, roll_axis["direction"])
eccentricity = math.sqrt(dot(cross_delta, cross_delta) / dot(roll_axis["direction"], roll_axis["direction"]))
result["lens_barrel_axis"] = {"point_mm": camera_point, "direction": camera_axis,
                             "radial_offset_from_roll_axis_mm": eccentricity,
                             "optical_entrance_pupil_measured": False}
result["illustrative_parallax_at_250mm"] = [
    {"roll_deg": angle, "transverse_displacement_mm": 2*eccentricity*math.sin(math.radians(angle/2)),
     "angular_scale_deg": math.degrees(math.atan(2*eccentricity*math.sin(math.radians(angle/2))/250))}
    for angle in (10, 90)
]
assert "UPDATED=True" in axes_log
assert all(f"AFTER_RELEASE={name} TRANSLATIONS=0 ROTATIONS=1" in axes_log
           for name in ("Base_Z:1", "Base_Z:2", "cajita:1"))
result["in_memory_release_one_rotation_each_stage"] = True
(review / "verificacion_paquete.json").write_text(json.dumps(result, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k not in {"interferences_at_saved_pose", "actuator_axes"}}, indent=2))
