import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const G = require("../geometry.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");

const model = {
  screenWidthMm: 596.736,
  screenHeightMm: 335.664,
  curveRadiusMm: 1000,
  cameraDistanceMm: 500,
  screenWidthPx: 2560,
  screenHeightPx: 1440,
};
const camera = {
  horizontalFovDeg: 25,
  sensorWidth: 160,
  sensorHeight: 120,
  lensK1: 0,
  lensK2: 0,
};
const skyBasis = G.celestialBasis(83.8, -5.4, 0);
const viewBasis = G.cameraBasis(0, 0, 0);
let starsOnScreen = 0;
let starsInCamera = 0;

for (const [hip, ra, dec, magnitude] of globalThis.HIPPARCOS_CATALOG.stars) {
  if (magnitude > 6.5) break;
  const ray = G.celestialToMonitorRay(G.celestialUnitVector(ra, dec), skyBasis);
  if (!ray || !G.projectMonitorRayToScreen(ray, model)) continue;
  starsOnScreen += 1;
  const cameraPoint = G.projectMonitorRayToCamera(ray, camera, viewBasis);
  if (cameraPoint?.inside) starsInCamera += 1;
}

assert.ok(starsOnScreen > 100, "La región inicial de Orión debe poblar el panel");
assert.ok(starsInCamera > 20, "La vista inicial de 25° debe contener suficientes estrellas de prueba");
assert.ok(starsInCamera < starsOnScreen, "El FOV de 25° no debe cubrir toda la región del panel");

console.log(`PASS default_scene: ${starsOnScreen} estrellas en panel, ${starsInCamera} dentro del FOV`);
