import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const E = require("../engine.js");
const fixed = require("../fixed_scene.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");

const manifest = JSON.parse(await readFile(new URL("../catalogo_referencia/orion_25cm_m5_v1/manifest.json", import.meta.url), "utf8"));
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const app = await readFile(new URL("../simulator.js", import.meta.url), "utf8");
const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

assert.deepEqual(fixed.configuration, manifest.configuration);
assert.deepEqual(fixed.reference, manifest.compensationSnapshot);
assert.equal(fixed.sceneHashFnv32, manifest.sceneHashFnv32);
assert.equal(fixed.imageY8Sha256, manifest.imageY8Sha256);
const scene = E.buildScene(fixed.configuration, fixed.reference, globalThis.HIPPARCOS_CATALOG.stars);
assert.equal(scene.hash, fixed.sceneHashFnv32);
assert.equal(sha256(scene.y8), fixed.imageY8Sha256);
assert.equal(scene.stars.length, 294);

const moved = fixed.movableConfig({
  cameraYaw: 12, cameraPitch: -6, cameraRoll: 20,
  showConstellationLines: true, showConstellationNames: true, showLabels: true,
  cameraDistanceCm: 50, horizontalFov: 60, centerRa: 10,
  magnitudeLimit: 7, starClarity: 0, starRadiusPx: 1,
  backgroundLevel: 255, curveRadiusMm: 400, lensK1: 0.5,
});
assert.deepEqual([moved.cameraYaw, moved.cameraPitch, moved.cameraRoll], [12, -6, 20]);
assert.equal(moved.showFovGuide, fixed.configuration.showFovGuide);
assert.equal(moved.showConstellationLines, true);
assert.equal(moved.showConstellationNames, true);
assert.equal(moved.showLabels, true);
for (const id of ["cameraDistanceCm", "horizontalFov", "centerRa", "magnitudeLimit", "starClarity",
  "starRadiusPx", "backgroundLevel", "curveRadiusMm", "lensK1"]) {
  assert.equal(moved[id], fixed.configuration[id], `${id} no debe alterar la escena`);
}
assert.equal(E.sceneKey(moved, fixed.reference), E.sceneKey(fixed.configuration, fixed.reference));
const originalFrame = E.renderCamera(scene, fixed.configuration);
const movedFrame = E.renderCamera(scene, moved);
assert.notEqual(originalFrame.hash, movedFrame.hash, "La vista de cámara sí debe moverse");

for (const id of fixed.guideIds) assert.ok(html.includes(`id="${id}"`), `Falta el control ${id}`);
assert.ok(html.indexOf('src="fixed_scene.js"') < html.indexOf('src="simulator.js"'));
console.log("PASS fixed_scene: referencia historica y motor de camara movil conservados");
