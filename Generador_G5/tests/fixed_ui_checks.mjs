import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { runInNewContext } from "node:vm";

const require = createRequire(import.meta.url);
const G = require("../geometry.js"), E = require("../engine.js"), fixed = require("../fixed_scene.js");
const rotating = require("../rotating_scene.js");
globalThis.window = globalThis;
require("../data/hipparcos_vmag_le_7.js");
require("../data/constellations.js");
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const app = await readFile(new URL("../simulator.js", import.meta.url), "utf8");

const elements = new Map();
class FakeContext {
  drawImageCount = 0;
  fillTextCount = 0;
  createImageData(width, height) { return { data: new Uint8ClampedArray(width * height * 4) }; }
  putImageData() {}
  clearRect() {}
  save() {}
  restore() {}
  beginPath() {}
  moveTo() {}
  lineTo() {}
  stroke() {}
  setLineDash() {}
  fillText() { this.fillTextCount += 1; }
  measureText(value) { return { width: value.length * 12 }; }
  drawImage() { this.drawImageCount += 1; }
}
class FakeElement {
  constructor(id = "") { this.listeners = {}; this.dataset = {}; this.hidden = false; this.value = ""; this.checked = false; if (id) this.id = id; }
  set id(value) { this._id = value; elements.set(value, this); }
  get id() { return this._id; }
  append() {}
  setAttribute() {}
  addEventListener(name, callback) { this.listeners[name] = callback; }
  getContext() { return this.context ||= new FakeContext(); }
  getBoundingClientRect() { return { width: 2560, height: 1440 }; }
  blur() {}
  get valueAsNumber() { return Number(this.value); }
}
for (const [, id] of html.matchAll(/id="([^"]+)"/g)) new FakeElement(id);
const docListeners = {};
const document = {
  getElementById: (id) => elements.get(id) || null,
  createElement: () => new FakeElement(),
  addEventListener: (name, callback) => { docListeners[name] = callback; },
  activeElement: null,
  fullscreenElement: false,
};
const window = {
  StarSimulatorEngine: E, StarGeometry: G, StarTrackerFixedScene: fixed,
  StarTrackerRotatingScene: rotating,
  HIPPARCOS_CATALOG: globalThis.HIPPARCOS_CATALOG, CONSTELLATIONS: globalThis.CONSTELLATIONS,
  devicePixelRatio: 1, addEventListener() {},
};
const queue = [];
const storage = JSON.stringify({ cameraYaw: 12, magnitudeLimit: 7, cameraDistanceCm: 50, starClarity: 0 });
runInNewContext(app, {
  window, document, HTMLElement: FakeElement,
  localStorage: { getItem: (key) => key === "star-tracker-g5-fixed-orion25-v1" ? storage : null, setItem() {} },
  requestAnimationFrame: (callback) => { queue.push(callback); return queue.length; },
  setTimeout: () => 1, clearTimeout() {},
  Uint8ClampedArray, Number, Math, JSON, Object, Boolean,
});
function flush() { while (queue.length) queue.shift()(); }

const screen = elements.get("screenCanvas"), guide = elements.get("guideCanvas");
const preview = elements.get("cameraPreview");
assert.equal(screen.dataset.sceneHash, fixed.sceneHashFnv32);
assert.equal(elements.get("screenStarCount").textContent, 294);
assert.equal(screen.context.drawImageCount, 1);
const originalFrame = preview.dataset.frameHash;
assert.equal(elements.has("cameraYaw"), false, "No deben existir controles de camara movil");
const yaw = elements.get("skyYaw");
yaw.value = "12";
yaw.listeners.input();
flush();
assert.notEqual(screen.dataset.sceneHash, fixed.sceneHashFnv32);
assert.equal(screen.context.drawImageCount, 2, "Girar el cielo debe repintar el patron");
assert.notEqual(preview.dataset.frameHash, originalFrame);

for (const id of fixed.guideIds) {
  const checkbox = elements.get(id);
  assert.ok(checkbox, `Falta ${id}`);
  checkbox.checked = true;
  checkbox.listeners.change();
  flush();
  assert.equal(screen.context.drawImageCount, 2, `${id} no debe modificar la imagen`);
}
assert.ok(guide.context.fillTextCount > 0, "Nombres e HIP deben producir guías de texto");
docListeners.keydown({ key: "m", ctrlKey: false, metaKey: false, altKey: false, repeat: false, preventDefault() {} });
assert.equal(elements.get("controlPanel").hidden, true);
assert.equal(guide.hidden, true);
assert.equal(screen.context.drawImageCount, 2);
docListeners.keydown({ key: "m", ctrlKey: false, metaKey: false, altKey: false, repeat: false, preventDefault() {} });
assert.equal(elements.get("controlPanel").hidden, false);
assert.equal(guide.hidden, false);
elements.get("resetButton").listeners.click();
flush();
assert.equal(elements.get("skyYaw").value, 0);
assert.equal(screen.context.drawImageCount, 3);
assert.equal(screen.dataset.sceneHash, fixed.sceneHashFnv32);
assert.equal(preview.dataset.frameHash, originalFrame, "A-B-A debe recuperar el frame original");
const fov = elements.get("horizontalFov");
fov.value = "30"; fov.listeners.input(); flush();
assert.notEqual(preview.dataset.frameHash, originalFrame, "FOV debe actualizar el muestreo");
assert.equal(screen.dataset.sceneHash, fixed.sceneHashFnv32, "FOV no debe predeformar el patron");
const beforeOverview = preview.dataset.frameHash;
const overview = elements.get("sectorPreview");
const button = elements.get("overviewButton");
button.listeners.click();
assert.equal(preview.hidden, true);
assert.equal(overview.hidden, false);
assert.equal(overview.dataset.sceneHash, screen.dataset.sceneHash);
assert.equal(yaw.disabled, true);
assert.equal(elements.get("skyYawRange").disabled, true);
assert.equal(fov.disabled, true);
assert.equal(elements.get("resetButton").disabled, true);
assert.equal(Number(fov.value), 30, "Vista general no cambia FOV");
assert.equal(Number(elements.get("cameraDistanceCm").value), 25, "Vista general no cambia distancia");
assert.equal(preview.dataset.frameHash, beforeOverview);
yaw.value = "35"; yaw.listeners.input(); flush();
assert.equal(yaw.value, 0, "Los giros quedan bloqueados en la vista de consulta");
button.listeners.click();
assert.equal(preview.hidden, false);
assert.equal(overview.hidden, true);
assert.equal(yaw.disabled, false);
assert.equal(fov.disabled, false);
assert.equal(preview.dataset.frameHash, beforeOverview, "Volver conserva el encuadre");
console.log("PASS rotating_ui: cielo variable, camara fija, guias separadas, A-B-A y cambio FOV");
console.log("PASS overview_ui: sector completo, controles bloqueados, FOV/distancia y frame conservados");
