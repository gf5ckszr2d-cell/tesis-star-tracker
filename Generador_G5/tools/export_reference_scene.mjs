import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { createRequire } from "node:module";
import { deflateSync } from "node:zlib";

const require = createRequire(import.meta.url);
const E = require("../engine.js");
const G = require("../geometry.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const label = Buffer.from(type, "ascii");
  const size = Buffer.alloc(4);
  size.writeUInt32BE(data.length);
  const check = Buffer.alloc(4);
  check.writeUInt32BE(crc32(Buffer.concat([label, data])));
  return Buffer.concat([size, label, data, check]);
}

function grayPng(y8, width, height) {
  assert.equal(y8.length, width * height);
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // 8 bits, escala de grises, sin alpha.
  const scanlines = Buffer.alloc(height * (width + 1));
  for (let y = 0; y < height; y += 1) {
    scanlines[y * (width + 1)] = 0; // Filtro PNG None.
    Buffer.from(y8.buffer, y8.byteOffset + y * width, width).copy(scanlines, y * (width + 1) + 1);
  }
  return Buffer.concat([
    Buffer.from("89504e470d0a1a0a", "hex"),
    chunk("IHDR", header), chunk("IDAT", deflateSync(scanlines)), chunk("IEND", Buffer.alloc(0)),
  ]);
}

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function parseArguments(args) {
  const result = { config: null, preset: null, out: resolve("Simulador_cielo_G5/catalogo_referencia/orion_base") };
  for (let i = 0; i < args.length; i += 2) {
    if (args[i] === "--config" && args[i + 1]) result.config = resolve(args[i + 1]);
    else if (args[i] === "--preset" && args[i + 1]) result.preset = args[i + 1];
    else if (args[i] === "--out" && args[i + 1]) result.out = resolve(args[i + 1]);
    else throw new Error("Uso: node export_reference_scene.mjs [--config exportacion_g5.json | --preset orion_25cm_m5_v1] [--out directorio_nuevo]");
  }
  assert.ok(!result.config || !result.preset, "Usa --config o --preset, no ambos");
  return result;
}

const { config, preset, out } = parseArguments(process.argv.slice(2));
const catalog = globalThis.HIPPARCOS_CATALOG;
let configuration = E.sanitize();
let reference = E.snapshot(configuration);
let source = "Valores iniciales de engine.js (Orion)";
let exported = null;
if (config) {
  exported = JSON.parse(await readFile(config, "utf8"));
  assert.equal(exported.format, "STAR_TRACKER_G5_SIM_CONFIG_V3", "Se requiere una exportacion V3 del G5");
  assert.ok(exported.configuration && exported.compensationSnapshot, "Faltan configuracion o referencia aplicada");
  assert.equal(exported.catalog?.source_sha256, catalog.metadata.source_sha256, "El catalogo Hipparcos no coincide");
  configuration = E.sanitize(exported.configuration);
  reference = E.snapshot(E.sanitize({ ...configuration, ...exported.compensationSnapshot }));
  source = config;
} else if (preset) {
  assert.equal(preset, "orion_25cm_m5_v1", "Preset desconocido");
  configuration = E.sanitize({ cameraDistanceCm: 25, horizontalFov: 25,
    magnitudeLimit: 5, starClarity: 100, starRadiusPx: 8 });
  reference = E.snapshot(configuration);
  source = "Preset de diseno orion_25cm_m5_v1";
}

const scene = E.buildScene(configuration, reference, catalog.stars);
if (config) {
  assert.equal(scene.hash, exported.sceneHash, "La imagen no coincide con el hash de la exportacion");
}
const rows = scene.stars.map((star) => {
  const [ux, uy, uz] = G.celestialUnitVector(star.ra, star.dec);
  return [star.hip, star.ra, star.dec, star.magnitude, star.xPx, star.yPx, ux, uy, uz];
});
assert.equal(new Set(rows.map((row) => row[0])).size, rows.length, "HIP duplicado en la escena");
const header = "HIP,RA_deg,Dec_deg,Vmag,screen_x_px,screen_y_px,ICRS_x,ICRS_y,ICRS_z";
const csv = `${header}\n${rows.map((row) => row.join(",")).join("\n")}\n`;
const png = grayPng(scene.y8, 2560, 1440);
const manifest = {
  format: "STAR_TRACKER_G5_REFERENCE_SCENE_V1",
  status: "SIMULATED_UNCALIBRATED",
  source,
  catalogSource: catalog.metadata,
  configuration,
  compensationSnapshot: reference,
  dimensionsPx: [2560, 1440],
  starCountOnScreen: rows.length,
  imageY8Sha256: sha256(scene.y8),
  sceneHashFnv32: scene.hash,
  imagePngSha256: sha256(png),
  catalogCsvSha256: sha256(Buffer.from(csv, "utf8")),
  note: "Solo estrellas visibles en esta imagen. No es aun una ROM FPGA ni una deteccion garantizada.",
};
try {
  await access(out);
  throw new Error(`El directorio de salida ya existe: ${out}. Usa otro nombre; no se sobrescriben escenas.`);
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
await mkdir(out, { recursive: true });
await writeFile(resolve(out, "imagen_monitor_g5.png"), png, { flag: "wx" });
await writeFile(resolve(out, "estrellas_imagen.csv"), csv, { flag: "wx" });
await writeFile(resolve(out, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, { flag: "wx" });
console.log(`${rows.length} estrellas, imagen Y8 SHA-256 ${manifest.imageY8Sha256}`);
console.log(out);
