import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { createHash } from "node:crypto";
import { deflateSync } from "node:zlib";
const S = createRequire(import.meta.url)("../synthetic_pattern.js");
const args = process.argv.slice(2), settings = {};
let out;
for (let i = 0; i < args.length; i += 2) {
  const [flag, value] = args.slice(i, i + 2);
  assert.ok(value !== undefined, "Falta valor: " + flag);
  if (flag === "--out") out = resolve(value);
  else {
    assert.ok(["--seed", "--diameter", "--level"].includes(flag), "Opción desconocida: " + flag);
    const key = flag.slice(2), n = Number(value);
    assert.ok(Number.isSafeInteger(n), "Valor entero requerido: " + flag);
    settings[key] = n;
  }
}
assert.ok(out, "Uso: node tools/export_synthetic_pattern.mjs --out carpeta_nueva [--seed entero --diameter 8..64 --level 40..255]");
const scene = S.build(settings);
for (const key of Object.keys(settings)) assert.equal(scene.settings[key], settings[key], "Fuera de rango: " + key);
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
const box = S.findEight(scene), reference = S.manifest(scene, box);
const outputs = { "patron_g5.png": png(S.raster(scene), S.WIDTH, S.HEIGHT),
  "referencia.json": JSON.stringify(reference, null, 2) + "\n", "estrellas.csv": S.csv(scene, box) };
const hashes = Object.fromEntries(Object.entries(outputs).map(([name, bytes]) => [name, createHash("sha256").update(bytes).digest("hex")]));
// Never overwrite an existing reference, even partially.
await mkdir(out);
for (const [name, bytes] of Object.entries(outputs)) await writeFile(resolve(out, name), bytes, { flag: "wx" });
await writeFile(resolve(out, "manifest.json"), JSON.stringify({ patternId: scene.patternId, outputsSha256: hashes }, null, 2) + "\n", { flag: "wx" });
console.log(`PASS: ${scene.patternId}; 48 puntos; ${S.visible(scene, box).length} centros en recorte digital; ${out}`);
