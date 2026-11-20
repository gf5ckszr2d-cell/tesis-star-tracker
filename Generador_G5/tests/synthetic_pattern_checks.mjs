import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { createHash } from "node:crypto";
const S = createRequire(import.meta.url)("../synthetic_pattern.js");
const scene = S.build(), pixels = S.raster(scene), box = S.findEight(scene);
assert.deepEqual(S.build(), scene, "La misma semilla debe conservar exactamente el patrón");
assert.equal(scene.stars.length, 48);
assert.equal(new Set(scene.stars.map(s => `${s.row},${s.column}`)).size, 48);
assert.equal(new Set(scene.stars.map(s => s.id)).size, 48);
assert.equal(S.visible(scene, box).length, 8, "La referencia inicial debe tener ocho centros en su recorte");
assert.notDeepEqual(S.build({ seed: 20261120 }).stars, scene.stars);
assert.deepEqual(S.build({ diameter: 64, level: 80 }).stars, scene.stars, "Brillo y tamaño conservan posiciones e identidades");
for (const star of scene.stars) {
  assert.equal(Math.floor(star.x / 320) + 1, star.column);
  assert.equal(Math.floor(star.y / 240) + 1, star.row);
  assert.equal(pixels[star.y * S.WIDTH + star.x], 255);
  for (const other of scene.stars) if (star !== other)
    assert.ok(Math.hypot(star.x - other.x, star.y - other.y) > 64, "Las fuentes no deben fusionarse en el patrón digital, incluso con diámetro máximo");
}
assert.equal(pixels[0], 0);
assert.equal(pixels.length, 2560 * 1440);
assert.equal(S.csv(scene, box).trim().split("\n").length, 49);
assert.deepEqual(JSON.parse(JSON.stringify(S.manifest(scene, box))).stars, scene.stars);
const original = createHash("sha256").update(pixels).digest("hex");
S.visible(scene, S.crop({ x: 300, y: 200, width: 640 }));
assert.equal(createHash("sha256").update(S.raster(scene)).digest("hex"), original, "Mover el recorte no cambia el estímulo");
for (const seed of [0, 1, 42, 20261120, 4294967295]) {
  const sample = S.build({ seed }), sampleBox = S.findEight(sample);
  assert.equal(S.visible(sample, sampleBox).length, 8);
  assert.ok(sampleBox.x >= 0 && sampleBox.x + sampleBox.width <= S.WIDTH);
  assert.ok(sampleBox.y >= 0 && sampleBox.y + sampleBox.height <= S.HEIGHT);
}
console.log(`PASS: 48 fuentes, familia única, semilla reproducible, recorte de ocho, variaciones y exportación; SHA256=${original}; recorte=${JSON.stringify(box)}`);
