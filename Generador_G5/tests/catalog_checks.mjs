import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");

const catalog = globalThis.HIPPARCOS_CATALOG;
assert.ok(catalog, "El catálogo debe publicar HIPPARCOS_CATALOG");
assert.equal(catalog.metadata.record_format.join("|"), "HIP|RA_deg|Dec_deg|Vmag");
assert.match(catalog.metadata.source_sha256, /^[A-F0-9]{64}$/);
assert.equal(catalog.stars.length, catalog.metadata.selected_records);
assert.ok(catalog.stars.length > 10_000, "El subconjunto Vmag<=7 no debe estar truncado");

const seen = new Set();
let previousMagnitude = -Infinity;
for (const [hip, ra, dec, magnitude] of catalog.stars) {
  assert.ok(!seen.has(hip), `HIP duplicado: ${hip}`);
  seen.add(hip);
  assert.ok(ra >= 0 && ra < 360, `AR fuera de rango para HIP ${hip}`);
  assert.ok(dec >= -90 && dec <= 90, `Dec fuera de rango para HIP ${hip}`);
  assert.ok(magnitude <= 7, `Magnitud fuera del filtro para HIP ${hip}`);
  assert.ok(magnitude >= previousMagnitude, "El catálogo debe estar ordenado por magnitud");
  previousMagnitude = magnitude;
}

const sirius = catalog.stars.find(([hip]) => hip === 32349);
assert.ok(sirius, "Sirio (HIP 32349) debe estar presente");
assert.ok(Math.abs(sirius[1] - 101.287) < 0.01, "AR de Sirio inesperada");
assert.ok(Math.abs(sirius[2] + 16.716) < 0.01, "Dec de Sirio inesperada");
assert.ok(Math.abs(sirius[3] + 1.44) < 0.02, "Magnitud V de Sirio inesperada");

console.log(`PASS catalog_checks: ${catalog.stars.length} estrellas únicas, filtro y Sirio verificados`);
