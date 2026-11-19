import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const G = require("../geometry.js");

const model = {
  screenWidthMm: 596.736,
  screenHeightMm: 335.664,
  curveRadiusMm: 1000,
  cameraDistanceMm: 1000,
  screenWidthPx: 2560,
  screenHeightPx: 1440,
};

function near(actual, expected, tolerance, message) {
  assert.ok(Math.abs(actual - expected) <= tolerance, `${message}: ${actual} no está cerca de ${expected}`);
}

const center = G.projectMonitorRayToScreen([0, 0, -1], model);
assert.ok(center, "El rayo central debe intersectar el panel");
near(center.xPx, 1280, 1e-9, "Centro horizontal");
near(center.yPx, 720, 1e-9, "Centro vertical");
near(center.point[2], 0, 1e-9, "El centro del panel está en z=0");

const coverageAtRadiusCenter = G.screenAngularCoverage(model);
near(coverageAtRadiusCenter.horizontalDeg, G.radToDeg(model.screenWidthMm / model.curveRadiusMm), 1e-9, "Cobertura horizontal desde el centro 1000R");

const closeModel = { ...model, cameraDistanceMm: 700 };
const closeCoverage = G.screenAngularCoverage(closeModel);
assert.ok(closeCoverage.horizontalDeg > 45, "A 700 mm el panel debe cubrir más de 45° horizontales");
assert.ok(closeCoverage.horizontalDeg > 25 * 1.8, "El FOV de 25° debe permitir varias regiones horizontales");

const verticalFov = G.cameraVerticalFov(25, 160, 120);
near(verticalFov, 18.880527, 1e-5, "FOV vertical 4:3");

const footprintCamera = { horizontalFovDeg: 25, sensorWidth: 160, sensorHeight: 120, lensK1: 0, lensK2: 0 };
const centralBasis = G.cameraBasis(0, 0, 0);
for (const [distanceMm, expectedWidthMm, expectedHeightMm] of [
  [300, 132.15, 99.76],
  [500, 219.47, 166.27],
  [700, 306.38, 232.78],
]) {
  const footprint = G.cameraFootprint(footprintCamera, centralBasis, { ...model, cameraDistanceMm: distanceMm });
  assert.ok(footprint, `Debe existir huella central a ${distanceMm} mm`);
  assert.equal(footprint.clipped, false, `La huella central no debe recortarse a ${distanceMm} mm`);
  near(footprint.widthMm, expectedWidthMm, 0.02, `Ancho de huella a ${distanceMm} mm`);
  near(footprint.heightMm, expectedHeightMm, 0.02, `Alto de huella a ${distanceMm} mm`);
}

const upperEdge = G.screenSurfacePoint(model.screenWidthMm / (2 * model.curveRadiusMm), model.screenHeightMm / 2, model);
const lowerEdge = G.screenSurfacePoint(model.screenWidthMm / (2 * model.curveRadiusMm), -model.screenHeightMm / 2, model);
near(upperEdge[2], lowerEdge[2], 1e-12, "La pantalla no tiene curvatura vertical");
assert.ok(upperEdge[2] > 0, "Los extremos del panel curvo deben acercarse al pivote");

const yawed = G.cameraBasis(10, 0, 0);
assert.ok(yawed.forward[0] > 0, "Yaw positivo debe apuntar hacia la derecha del panel");
near(Math.hypot(...yawed.forward), 1, 1e-12, "Base de cámara normalizada");

const celestial = G.celestialBasis(83.8, -5.4, 0);
const centerStarRay = G.celestialToMonitorRay(G.celestialUnitVector(83.8, -5.4), celestial);
assert.ok(centerStarRay, "La dirección central celeste debe ser visible");
near(centerStarRay[0], 0, 1e-12, "Centro celeste X");
near(centerStarRay[1], 0, 1e-12, "Centro celeste Y");
near(centerStarRay[2], -1, 1e-12, "Centro celeste Z");

console.log("PASS geometry_checks: cilindro horizontal, vertical plana, distancia, huella FOV y rotaciones");
