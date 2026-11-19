import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const E = require("../engine.js"), G = require("../geometry.js");
const R = require("../rotating_scene.js"), fixed = require("../fixed_scene.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");
const stars = globalThis.HIPPARCOS_CATALOG.stars;
const dot = (a, b) => a.reduce((n, v, i) => n + v * b[i], 0);
const zero = R.configuration();
const initial = R.build(zero, stars);
assert.equal(initial.hash, fixed.sceneHashFnv32, "Estado cero conserva la referencia exacta");
assert.equal(initial.stars.length, 294);
const moved = R.configuration({ skyYaw: 12, skyPitch: -6, skyRotationRoll: 20,
  cameraYaw: 70, cameraPitch: 45, cameraRoll: 15 });
assert.deepEqual([moved.cameraYaw, moved.cameraPitch, moved.cameraRoll], [0, 0, 0]);
const scene = R.build(moved, stars);
assert.notEqual(scene.hash, initial.hash);
const rotate = R.transform(moved);
const a = rotate(83.8, -5.4), b = rotate(101.28854105, -16.71314306);
assert.ok(Math.abs(dot(a.baseRay, b.baseRay) - dot(a.ray, b.ray)) < 1e-12);
assert.ok(Math.abs(Math.hypot(...a.ray) - 1) < 1e-12);
const source = new Map(stars.map(row => [row[0], row]));
for (const s of scene.stars) {
  assert.equal(s.ra, source.get(s.hip)[1]);
  assert.equal(s.dec, source.get(s.hip)[2]);
  const physical = G.screenPointToRay(s.point, moved.cameraDistanceCm * 10);
  assert.ok(Math.hypot(...physical.map((v, i) => v - s.rotatedRay[i])) < 1e-10);
}
// Rotation must not discard stars solely because they began behind the base hemisphere.
const backStar = [999999, (zero.centerRa + 180) % 360, -zero.centerDec, 1];
const halfTurn = R.configuration({ skyYaw: 75, skyPitch: 75, skyRotationRoll: 0 });
const p = R.transform(halfTurn)(backStar[1], backStar[2]);
assert.ok(p.ray.every(Number.isFinite));
assert.ok(Math.abs(dot(p.baseRay, p.baseRay) - 1) < 1e-12);
const entering = [999998, (zero.centerRa + 100) % 360, zero.centerDec, 1];
assert.equal(R.build(zero, [entering]).stars.length, 0);
assert.equal(R.build({ skyYaw: -75 }, [entering]).stars.length, 1,
  "Una estrella fuera del hemisferio inicial puede entrar al girar el cielo");
const map = E.buildCameraMap(zero);
const frame0 = E.renderCamera(initial, zero, map);
const frame1 = E.renderCamera(scene, moved, map);
assert.notEqual(frame0.hash, frame1.hash);
assert.deepEqual(E.snapshot(zero), E.snapshot(moved), "La camara no cambia entre estados");
assert.equal(R.build(zero, stars).hash, initial.hash, "A-B-A sin residuos");
const empty = R.build(moved, []);
assert.ok(empty.y8.every(v => v === 0));
assert.ok(E.renderCamera(empty, moved, map).y8.every(v => v === 0));
const changed = R.configuration({ cameraDistanceCm: 30, horizontalFov: 30 });
assert.notEqual(R.build(changed, stars).hash, initial.hash);
assert.notDeepEqual(E.snapshot(changed), E.snapshot(zero));
const withGuides = R.configuration({ ...moved, showLabels: true, showConstellationLines: true });
assert.equal(R.key(withGuides), R.key(moved), "Guias fuera de la identidad del estado");
const manifest = R.manifest(scene, frame1, globalThis.HIPPARCOS_CATALOG.metadata);
assert.equal(manifest.cameraFixed, true);
assert.equal(manifest.stateId, scene.stateId);
assert.equal(manifest.stars.length, scene.stars.length);
const csv = R.csv(scene).trimEnd().split("\n");
assert.equal(csv.length, scene.stars.length + 1);
assert.ok(csv.slice(1).every(row => row.startsWith(scene.stateId + ",")));
let minVisible = Infinity, maxVisible = 0;
for (const yaw of [-75, 0, 75]) for (const pitch of [-75, 0, 75]) for (const roll of [-180, 0, 180]) {
  const cfg = R.configuration({ skyYaw: yaw, skyPitch: pitch, skyRotationRoll: roll });
  const sample = R.build(cfg, stars);
  assert.equal(new Set(sample.stars.map(s => s.hip)).size, sample.stars.length);
  for (const s of sample.stars) {
    assert.ok(s.xPx >= 0 && s.xPx < 2560 && s.yPx >= 0 && s.yPx < 1440);
    assert.ok(Math.abs(dot(s.rotatedRay, s.rotatedRay) - 1) < 1e-12);
  }
  const view = E.renderCamera(sample, cfg, map);
  minVisible = Math.min(minVisible, view.starCount); maxVisible = Math.max(maxVisible, view.starCount);
}
console.log(`PASS rotating_grid: 27 estados, ${minVisible}-${maxVisible} centros geometricos/FOV (sin atribuir detecciones fisicas)`);
console.log(`PASS rotating_scene: referencia cero, rotacion rigida, HIP/rayos, camara fija, A-B-A, vacio y exportacion (${scene.stars.length} fuentes)`);
