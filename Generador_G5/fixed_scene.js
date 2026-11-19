(function attachFixedScene(root) {
  "use strict";
  const E = typeof module !== "undefined" && module.exports ? require("./engine.js") : root.StarSimulatorEngine;
  // Debe coincidir con catalogo_referencia/orion_25cm_m5_v1/manifest.json.
  const configuration = Object.freeze(E.sanitize({
    regionPreset: "orion", centerRa: 83.8, centerDec: -5.4, skyRoll: 0,
    magnitudeLimit: 5, screenWidthMm: 596.736, screenHeightMm: 335.664,
    curveRadiusMm: 1000, cameraDistanceCm: 25, horizontalFov: 25,
    cameraYaw: 0, cameraPitch: 0, cameraRoll: 0, lensK1: 0, lensK2: 0,
    backgroundLevel: 0, peakLevel: 255, starClarity: 100, starRadiusPx: 8,
    cameraPsfSigma: 0.55, showFovGuide: true, showLabels: false,
    showConstellationLines: false, showConstellationNames: false, pixelTest: false,
  }));
  const reference = Object.freeze(E.snapshot(configuration));
  const poseIds = Object.freeze(["cameraYaw", "cameraPitch", "cameraRoll"]);
  const guideIds = Object.freeze(["showFovGuide", "showConstellationLines", "showConstellationNames", "showLabels"]);
  function movableConfig(raw = {}) {
    const next = { ...configuration };
    for (const id of poseIds) if (raw[id] !== "" && raw[id] != null && Number.isFinite(Number(raw[id]))) next[id] = Number(raw[id]);
    for (const id of guideIds) if (typeof raw[id] === "boolean") next[id] = raw[id];
    return E.sanitize(next);
  }
  const api = Object.freeze({
    name: "orion_25cm_m5_v1",
    configuration,
    reference,
    poseIds,
    guideIds,
    movableConfig,
    sceneHashFnv32: "c682b617",
    imageY8Sha256: "13202f2ebe61a48d77d5e278b4b54af9ef90fb1008c035fb6edac6ff75324f33",
  });
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  root.StarTrackerFixedScene = api;
}(typeof globalThis !== "undefined" ? globalThis : this));
