import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const G = require("../geometry.js"), E = require("../engine.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");
require("../data/constellations.js");
const catalog = HIPPARCOS_CATALOG.stars;
const sha = (bytes) => createHash("sha256").update(bytes).digest("hex");
const c = E.sanitize();
const reference = E.snapshot(c);
const original = E.buildScene(c, reference, catalog);
const originalHash = sha(original.y8);
const map = E.buildCameraMap(c);
const originalFrame = E.renderCamera(original, c, map);
assert.equal(originalFrame.y8.length, 19200);
assert.ok(originalFrame.starCount > 20 && originalFrame.starCount < original.stars.length);
assert.ok(originalFrame.y8.some((v) => v > 0));
const changes = [
  { cameraDistanceCm: 30 }, { cameraDistanceCm: 70 }, { horizontalFov: 35 },
  { cameraYaw: 15 }, { cameraPitch: 10 }, { cameraRoll: 45 },
];
for (const change of changes) {
  const next = E.sanitize({ ...c, ...change });
  assert.equal(E.sceneKey(next, reference), E.sceneKey(c, reference), "Camera must not invalidate fixed texture");
  const regenerated = E.buildScene(next, reference, catalog);
  assert.equal(sha(regenerated.y8), originalHash, "Physical changes cannot zoom the monitor image");
  const viewed = E.renderCamera(original, next);
  assert.notEqual(sha(viewed.y8), sha(originalFrame.y8), "Camera image must respond to " + JSON.stringify(change));
}
console.log("PASS static_scene: SHA-256 invariant for distance, FOV and all three axes; preview changes");

for (let i = 0; i < 100; i += 1) {
  assert.equal(sha(E.renderCamera(original, c, map).y8), sha(originalFrame.y8), "Accumulation after redraw " + i);
}
const moved = E.sanitize({ ...c, cameraYaw: 20 });
E.renderCamera(original, moved);
assert.equal(sha(E.renderCamera(original, c, map).y8), sha(originalFrame.y8));
const empty = E.buildScene({ ...c, magnitudeLimit: -2 }, reference, catalog);
assert.ok(E.renderCamera(empty, c, map).y8.every((v) => v === 0), "Empty scene must clear every previous pixel");
console.log("PASS clean_preview: 100 byte-identical redraws, A-B-A, zero-star frame clears to black");

const shifted = E.sanitize({ ...c, cameraDistanceCm: 30, cameraYaw: 12, cameraPitch: 8, cameraRoll: 20, lensK1: 0.2, lensK2: 0.04 });
const applied = E.buildScene(shifted, E.snapshot(shifted), catalog);
assert.notEqual(sha(applied.y8), originalHash, "Explicit application changes pattern");
const shiftedCam = E.camera(shifted), shiftedBasis = E.basis(shifted);
let verified = 0;
for (const star of applied.stars) {
  const expected = G.projectMonitorRayToCamera(star.idealRay, { ...shiftedCam, lensK1: 0, lensK2: 0 }, shiftedBasis);
  if (!expected?.inside) continue;
  const actual = G.projectMonitorRayToCamera(G.screenPointToRay(star.point, shifted.cameraDistanceCm * 10), shiftedCam, shiftedBasis);
  assert.ok(actual);
  assert.ok(Math.hypot(actual.xPx - expected.xPx, actual.yPx - expected.yPx) < 1e-7);
  verified += 1;
}
assert.ok(verified > 10);
assert.equal(sha(E.buildScene({ ...shifted, cameraYaw: 30 }, E.snapshot(shifted), catalog).y8), sha(applied.y8));
console.log("PASS compensation: " + verified + " compensated centroids match ideal coordinates; pattern remains frozen");

for (const coefficients of [[0, 0], [0.2, 0.05], [-0.2, 0.03]]) {
  const cam = { ...E.camera(c), lensK1: coefficients[0], lensK2: coefficients[1] };
  for (const [x, y] of [[0, 0], [80, 60], [160, 120], [12.5, 48.5]]) {
    const ray = G.cameraPixelRay(x, y, cam, E.basis(c));
    assert.ok(ray);
    const pixel = G.projectMonitorRayToCamera(ray, cam, E.basis(c));
    assert.ok(Math.hypot(pixel.xPx - x, pixel.yPx - y) < 1e-8);
  }
}
assert.equal(E.compensationValid({ ...c, horizontalFov: 90, lensK1: -1, lensK2: 0 }), false);
const away = E.renderCamera(original, { ...c, cameraYaw: 75 });
assert.equal(away.coverage, 0);
assert.ok(away.y8.every((v) => v === 0));
const large = E.renderCamera(original, { ...c, cameraDistanceCm: 200, horizontalFov: 90 });
assert.ok(large.coverage > 0 && large.coverage < 1);
console.log("PASS rays: lens inversion, rejection of folds, camera off-panel and panel inside oversized FOV");

for (const value of [0, 80, 100]) {
  const state = { ...c, starClarity: value };
  assert.ok(E.level(0, state) > E.level(3, state));
  assert.ok(E.level(3, state) > E.level(6, state));
}
assert.ok(E.level(6, { ...c, starClarity: 100 }) > E.level(6, { ...c, starClarity: 0 }));
assert.ok(E.level(6, { ...c, starClarity: 100 }) < 255);
assert.equal(E.level(1, { ...c, peakLevel: 0, backgroundLevel: 0 }), 0);
assert.equal(E.level(1, { ...c, peakLevel: 255, backgroundLevel: 255 }), 255);
const saved = E.migrate({ ...c, cameraDistanceCm: 70, cameraYaw: 15, lensK1: 0.2 });
assert.equal(saved.compensationSnapshot.cameraDistanceCm, 70);
assert.equal(saved.compensationSnapshot.lensK1, 0, "V2 never prewarped the pattern");
const roundtrip = E.migrate({ configuration: shifted, compensationSnapshot: E.snapshot(c) });
assert.deepEqual(roundtrip.compensationSnapshot, E.snapshot(c));
assert.equal(E.sanitize({ cameraYaw: 100, cameraPitch: -100, starClarity: 101 }).cameraYaw, 75);
assert.equal(E.sanitize({ cameraPitch: -100 }).cameraPitch, -75);
assert.equal(E.sanitize({ cameraDistanceCm: "" }).cameraDistanceCm, 50);
console.log("PASS configuration: range endpoints, photometric ordering, V2 migration, frozen V3 reference");

const figures = CONSTELLATIONS.constellations;
assert.equal(new Set(figures.map((f) => f.iau)).size, 88);
assert.match(CONSTELLATIONS.metadata.source_sha256, /^[A-F0-9]{64}$/);
const byHip = new Map(catalog.map((s) => [s[0], s]));
for (const fig of figures) for (const line of fig.lines) {
  assert.ok(line.length >= 2);
  for (const hip of line) assert.ok(byHip.has(hip), "Unresolved HIP " + hip);
}
const visible = figures.filter((f) => f.lines.some((line) => line.slice(1).some((hip, i) => {
  const a = byHip.get(line[i]), b = byHip.get(hip);
  return original.project(a[1], a[2]) && original.project(b[1], b[2]);
})));
assert.ok(visible.some((f) => f.iau === "Ori"));
assert.ok(visible.length >= 3);
const diagnostic = { ...c, showLabels: true, showConstellationLines: true, showConstellationNames: true, showFovGuide: true };
assert.equal(E.sceneKey(diagnostic, reference), E.sceneKey(c, reference));
assert.equal(sha(E.renderCamera(original, diagnostic, map).y8), sha(originalFrame.y8));
console.log("PASS constellations: 88 validated, " + visible.length + " simultaneous near Orion; guides absent from camera frame");
console.log("Scene SHA-256: " + originalHash + "\nFrame SHA-256: " + sha(originalFrame.y8));
