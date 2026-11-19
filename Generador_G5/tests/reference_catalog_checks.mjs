import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { inflateSync } from "node:zlib";

const require = createRequire(import.meta.url);
const E = require("../engine.js");
const G = require("../geometry.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");
const sha256 = (value) => createHash("sha256").update(value).digest("hex");

async function checkReference(name, expectedCount) {
  const base = new URL(`../catalogo_referencia/${name}/`, import.meta.url);
  const [manifest, csv, png] = await Promise.all([
    readFile(new URL("manifest.json", base), "utf8").then(JSON.parse),
    readFile(new URL("estrellas_imagen.csv", base)),
    readFile(new URL("imagen_monitor_g5.png", base)),
  ]);
  assert.equal(manifest.catalogSource.source_sha256, globalThis.HIPPARCOS_CATALOG.metadata.source_sha256);
  assert.equal(manifest.starCountOnScreen, expectedCount);
  assert.equal(sha256(csv), manifest.catalogCsvSha256);
  assert.equal(sha256(png), manifest.imagePngSha256);
  const lines = csv.toString("utf8").trimEnd().split("\n");
  assert.equal(lines.length - 1, expectedCount);
  assert.equal(new Set(lines.slice(1).map((line) => line.split(",")[0])).size, expectedCount);

  const scene = E.buildScene(manifest.configuration, manifest.compensationSnapshot, globalThis.HIPPARCOS_CATALOG.stars);
  assert.equal(scene.stars.length, expectedCount);
  assert.equal(scene.hash, manifest.sceneHashFnv32);
  assert.equal(sha256(scene.y8), manifest.imageY8Sha256);
  for (let index = 0; index < scene.stars.length; index += 1) {
    const row = lines[index + 1].split(",").map(Number);
    const star = scene.stars[index];
    assert.deepEqual(row.slice(0, 6), [star.hip, star.ra, star.dec, star.magnitude, star.xPx, star.yPx]);
  }

  assert.equal(png.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
  assert.equal(png.readUInt32BE(16), 2560);
  assert.equal(png.readUInt32BE(20), 1440);
  assert.equal(png[25], 0, "PNG esperado en escala de grises");
  const idatOffset = 8 + 25;
  assert.equal(png.subarray(idatOffset + 4, idatOffset + 8).toString("ascii"), "IDAT");
  const raw = inflateSync(png.subarray(idatOffset + 8, idatOffset + 8 + png.readUInt32BE(idatOffset)));
  const y8 = Buffer.alloc(2560 * 1440);
  for (let y = 0; y < 1440; y += 1) {
    assert.equal(raw[y * 2561], 0);
    raw.copy(y8, y * 2560, y * 2561 + 1, (y + 1) * 2561);
  }
  assert.equal(sha256(y8), manifest.imageY8Sha256, "Los pixeles PNG deben igualar el buffer del monitor");
  console.log(`PASS reference_catalog ${name}: ${expectedCount} HIP y PNG Y8 identicos`);
  return { manifest, scene };
}

await checkReference("orion_base", 642);
const selected = await checkReference("orion_25cm_m5_v1", 294);
assert.equal(selected.manifest.configuration.cameraDistanceCm, 25);
assert.equal(selected.manifest.configuration.horizontalFov, 25);
assert.equal(selected.manifest.configuration.magnitudeLimit, 5);
assert.equal(selected.manifest.configuration.starClarity, 100);
assert.equal(selected.manifest.configuration.starRadiusPx, 8);
const rays = selected.scene.stars.map((star) => G.screenPointToRay(star.point, 250));
let minimum = Infinity, maximum = 0, poses = 0;
for (let yaw = -70; yaw <= 70; yaw += 1) for (let pitch = -36; pitch <= 36; pitch += 1) {
  const c = { ...selected.manifest.configuration, cameraYaw: yaw, cameraPitch: pitch };
  const basis = E.basis(c), cam = E.camera(c);
  const footprint = G.cameraFootprint(cam, basis, E.model(c));
  if (!footprint || footprint.clipped) continue;
  const count = rays.filter((ray) => G.projectMonitorRayToCamera(ray, cam, basis)?.inside).length;
  minimum = Math.min(minimum, count);
  maximum = Math.max(maximum, count);
  poses += 1;
}
assert.equal(poses, 3553);
assert.equal(minimum, 9);
assert.equal(maximum, 46);
assert.ok(maximum < 64, "La escena no debe agotar las 64 entradas con centros geometricos");
console.log(`PASS capacity_scene: ${poses} poses completas, ${minimum}-${maximum} centros geometricos/FOV`);

// Estimacion auxiliar sobre la vista QQVGA: no sustituye la simulacion del RTL.
function countThresholdComponents(y8) {
  const seen = new Uint8Array(y8.length);
  let count = 0;
  for (let pixel = 0; pixel < y8.length; pixel += 1) {
    if (seen[pixel] || y8[pixel] < 45) continue;
    const queue = [pixel];
    seen[pixel] = 1;
    let area = 0;
    for (let head = 0; head < queue.length; head += 1) {
      const current = queue[head], x = current % 160, y = Math.floor(current / 160);
      area += 1;
      for (let dy = -1; dy <= 1; dy += 1) for (let dx = -1; dx <= 1; dx += 1) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= 160 || ny < 0 || ny >= 120) continue;
        const neighbor = ny * 160 + nx;
        if (!seen[neighbor] && y8[neighbor] >= 45) {
          seen[neighbor] = 1;
          queue.push(neighbor);
        }
      }
    }
    if (area >= 2 && area <= 500) count += 1;
  }
  return count;
}

let approximateMin = Infinity, approximateMax = 0, sampledPoses = 0;
for (let yaw = -60; yaw <= 60; yaw += 5) for (let pitch = -30; pitch <= 30; pitch += 5) {
  const c = { ...selected.manifest.configuration, cameraYaw: yaw, cameraPitch: pitch };
  const footprint = G.cameraFootprint(E.camera(c), E.basis(c), E.model(c));
  if (!footprint || footprint.clipped) continue;
  const count = countThresholdComponents(E.renderCamera(selected.scene, c).y8);
  approximateMin = Math.min(approximateMin, count);
  approximateMax = Math.max(approximateMax, count);
  sampledPoses += 1;
}
assert.equal(sampledPoses, 141);
assert.ok(approximateMin >= 5 && approximateMax < 64);
console.log(`PASS QQVGA model: ${sampledPoses} poses muestreadas, ${approximateMin}-${approximateMax} componentes estimados`);
