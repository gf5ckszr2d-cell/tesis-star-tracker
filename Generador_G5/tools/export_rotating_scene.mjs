import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { createHash } from "node:crypto";
import { deflateSync } from "node:zlib";
const require = createRequire(import.meta.url);
const R = require("../rotating_scene.js"), E = require("../engine.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");
const raw = {}, args = process.argv.slice(2);
let out, configPath;
const flags = { "--yaw": "skyYaw", "--pitch": "skyPitch", "--roll": "skyRotationRoll",
  "--distance-cm": "cameraDistanceCm", "--fov": "horizontalFov" };
for (let i = 0; i < args.length; i += 2) {
  const [flag, value] = args.slice(i, i + 2);
  assert.ok(value !== undefined, "Falta valor para " + flag);
  if (flag === "--out") out = resolve(value);
  else if (flag === "--config") configPath = resolve(value);
  else {
    assert.ok(flags[flag], "Opcion desconocida: " + flag);
    const n = Number(value), [lo, hi] = R.limits[flags[flag]];
    assert.ok(Number.isFinite(n) && n >= lo && n <= hi, "Valor fuera de rango: " + flag);
    raw[flags[flag]] = n;
  }
}
assert.ok(out, "Uso: node tools/export_rotating_scene.mjs --out carpeta_nueva [--config estado.json] [--yaw grados --pitch grados --roll grados]");
let saved;
if (configPath) {
  saved = JSON.parse(await readFile(configPath, "utf8"));
  assert.equal(saved.format, "STAR_TRACKER_G5_ROTATING_STATE_V1");
  assert.equal(saved.catalog.source_sha256, globalThis.HIPPARCOS_CATALOG.metadata.source_sha256);
}
const scene = R.build({ ...saved?.configuration, ...raw }, globalThis.HIPPARCOS_CATALOG.stars);
const frame = E.renderCamera(scene, scene.configuration);
if (saved && Object.keys(raw).length === 0) {
  assert.equal(saved.stateId, scene.stateId);
  assert.equal(saved.sceneHashFnv32, scene.hash);
  assert.equal(saved.frameHashFnv32, frame.hash);
}
function crc(bytes) {
  let n = 0xffffffff;
  for (const x of bytes) { n ^= x; for (let i = 0; i < 8; i++) n = (n >>> 1) ^ (0xedb88320 & -(n & 1)); }
  return (n ^ 0xffffffff) >>> 0;
}
function chunk(type, bytes) {
  const tag = Buffer.from(type), size = Buffer.alloc(4), check = Buffer.alloc(4);
  size.writeUInt32BE(bytes.length); check.writeUInt32BE(crc(Buffer.concat([tag, bytes])));
  return Buffer.concat([size, tag, bytes, check]);
}
function png(bytes, width, height) {
  const header = Buffer.alloc(13), scan = Buffer.alloc((width + 1) * height);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8;
  for (let y = 0; y < height; y++) scan.set(bytes.subarray(y * width, (y + 1) * width), y * (width + 1) + 1);
  return Buffer.concat([Buffer.from("89504e470d0a1a0a", "hex"), chunk("IHDR", header), chunk("IDAT", deflateSync(scan)), chunk("IEND", Buffer.alloc(0))]);
}
const outputs = { "imagen_monitor_g5.png": png(scene.y8, 2560, 1440), "estrellas_estado.csv": R.csv(scene),
  "vista_estimada_y8.png": png(frame.y8, 160, 120), "vista_estimada_y8.raw": frame.y8 };
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const manifest = { ...R.manifest(scene, frame, globalThis.HIPPARCOS_CATALOG.metadata),
  outputsSha256: Object.fromEntries(Object.entries(outputs).map(([name, bytes]) => [name, sha(bytes)])) };
// mkdir without recursive refuses an existing directory. Reference outputs are never overwritten.
await mkdir(out);
for (const [name, bytes] of Object.entries(outputs)) await writeFile(resolve(out, name), bytes, { flag: "wx" });
await writeFile(resolve(out, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n", { flag: "wx" });
console.log(`PASS export_rotating: ${scene.stateId}, ${scene.stars.length} HIP, cinco archivos en ${out}`);
