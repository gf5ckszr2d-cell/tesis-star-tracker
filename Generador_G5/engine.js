(function attach(root) {
  "use strict";
  const G = typeof module !== "undefined" && module.exports ? require("./geometry.js") : root.StarGeometry;
  const defaults = Object.freeze({
    regionPreset: "orion", centerRa: 83.8, centerDec: -5.4, skyRoll: 0, magnitudeLimit: 6.5,
    screenWidthMm: 596.736, screenHeightMm: 335.664, curveRadiusMm: 1000,
    cameraDistanceCm: 50, horizontalFov: 25, cameraYaw: 0, cameraPitch: 0, cameraRoll: 0,
    lensK1: 0, lensK2: 0, showFovGuide: true, showLabels: false,
    showConstellationLines: false, showConstellationNames: false, pixelTest: false,
    backgroundLevel: 0, peakLevel: 255, starClarity: 80, starRadiusPx: 5.5, cameraPsfSigma: 0.55,
  });
  const limits = Object.freeze({
    centerRa: [0, 360, 0.1], centerDec: [-90, 90, 0.1], skyRoll: [-180, 180, 0.1],
    magnitudeLimit: [-2, 7, 0.1], screenWidthMm: [100, 1200, 0.001],
    screenHeightMm: [100, 800, 0.001], curveRadiusMm: [400, 3000, 1],
    cameraDistanceCm: [25, 200, 0.1], horizontalFov: [5, 90, 0.1],
    cameraYaw: [-75, 75, 0.1], cameraPitch: [-75, 75, 0.1], cameraRoll: [-180, 180, 0.1],
    lensK1: [-1, 1, 0.001], lensK2: [-1, 1, 0.001], backgroundLevel: [0, 255, 1],
    peakLevel: [0, 255, 1], starClarity: [0, 100, 1], starRadiusPx: [0.5, 12, 0.1],
    cameraPsfSigma: [0, 2, 0.05],
  });
  function sanitize(raw = {}) {
    const result = { ...defaults };
    for (const [key, value] of Object.entries(defaults)) {
      if (limits[key]) {
        const n = Number(raw[key]);
        if (raw[key] !== "" && raw[key] != null && Number.isFinite(n)) {
          result[key] = G.clamp(n, limits[key][0], limits[key][1]);
        }
      } else if (typeof value === "boolean") result[key] = raw[key] === undefined ? value : raw[key] === true;
      else if (typeof raw[key] === "string") result[key] = raw[key];
    }
    result.peakLevel = Math.max(result.backgroundLevel, result.peakLevel);
    return result;
  }
  const cameraKeys = ["cameraDistanceCm", "horizontalFov", "cameraYaw", "cameraPitch", "cameraRoll", "lensK1", "lensK2"];
  function snapshot(c) {
    return Object.fromEntries(cameraKeys.map((key) => [key, c[key]]));
  }
  function migrate(saved, legacy = false) {
    if (!saved || typeof saved !== "object") {
      const configuration = sanitize();
      return { configuration, compensationSnapshot: snapshot(configuration) };
    }
    const raw = { ...(saved.configuration || saved) };
    if (legacy) {
      if (Number.isFinite(raw.cameraDistanceMm)) raw.cameraDistanceCm = raw.cameraDistanceMm / 10;
      if (Number.isFinite(raw.responseGamma)) raw.starClarity = (0.6 - raw.responseGamma) / 0.0045;
    }
    const configuration = sanitize(raw);
    // V2 projected geometrically with no lens prewarp. Preserve that pattern on migration.
    const initial = { ...configuration, cameraYaw: 0, cameraPitch: 0, cameraRoll: 0, lensK1: 0, lensK2: 0 };
    const reference = saved.compensationSnapshot ? sanitize({ ...configuration, ...saved.compensationSnapshot }) : initial;
    return { configuration, compensationSnapshot: snapshot(reference) };
  }
  function model(c, distanceCm = c.cameraDistanceCm) {
    return { screenWidthMm: c.screenWidthMm, screenHeightMm: c.screenHeightMm, curveRadiusMm: c.curveRadiusMm,
      screenWidthPx: 2560, screenHeightPx: 1440, cameraDistanceMm: distanceCm * 10 };
  }
  function camera(c) {
    return { horizontalFovDeg: c.horizontalFov, sensorWidth: 160, sensorHeight: 120, lensK1: c.lensK1, lensK2: c.lensK2 };
  }
  const basis = (c) => G.cameraBasis(c.cameraYaw, c.cameraPitch, c.cameraRoll);
  function level(magnitude, c) {
    const flux = G.clamp(10 ** (-0.4 * (magnitude + 1.5)), 0, 1);
    const gamma = 0.60 - c.starClarity * 0.0045;
    return c.backgroundLevel + (c.peakLevel - c.backgroundLevel) * flux ** gamma;
  }
  function sceneKey(c, reference) {
    const keys = ["centerRa", "centerDec", "skyRoll", "magnitudeLimit", "screenWidthMm", "screenHeightMm",
      "curveRadiusMm", "backgroundLevel", "peakLevel", "starClarity", "starRadiusPx"];
    return JSON.stringify([keys.map((key) => c[key]), reference]);
  }
  function projector(c, reference) {
    const celestial = G.celestialBasis(c.centerRa, c.centerDec, c.skyRoll);
    const refBasis = basis(reference);
    const refModel = model(c, reference.cameraDistanceCm);
    return (ra, dec) => {
      const ideal = G.celestialToMonitorRay(G.celestialUnitVector(ra, dec), celestial);
      if (!ideal) return null;
      let physicalRay = ideal;
      if (reference.lensK1 !== 0 || reference.lensK2 !== 0) {
        const local = G.monitorRayToCamera(ideal, refBasis);
        if (local[2] <= 1e-8) return null;
        const tangent = G.undistortTangent(local[0] / local[2], local[1] / local[2], reference.lensK1, reference.lensK2);
        if (!tangent) return null;
        physicalRay = G.cameraRayToMonitor([tangent[0], tangent[1], 1], refBasis);
      }
      const hit = G.projectMonitorRayToScreen(physicalRay, refModel);
      return hit ? { ...hit, idealRay: ideal } : null;
    };
  }
  function buildScene(c, reference, catalog) {
    const m = model(c, reference.cameraDistanceCm);
    const project = projector(c, reference);
    const stars = [];
    const pixels = new Float32Array(m.screenWidthPx * m.screenHeightPx);
    pixels.fill(c.backgroundLevel);
    for (const [hip, ra, dec, magnitude] of catalog) {
      if (magnitude > c.magnitudeLimit) continue;
      const hit = project(ra, dec);
      if (!hit) continue;
      const brightness = level(magnitude, c);
      const sigma = Math.max(0.2, c.starRadiusPx / 2.5);
      const radius = Math.ceil(3 * sigma);
      stars.push({ hip, magnitude, ra, dec, ...hit });
      for (let y = Math.max(0, Math.floor(hit.yPx - radius)); y <= Math.min(1439, Math.ceil(hit.yPx + radius)); y += 1) {
        for (let x = Math.max(0, Math.floor(hit.xPx - radius)); x <= Math.min(2559, Math.ceil(hit.xPx + radius)); x += 1) {
          const r2 = (x + 0.5 - hit.xPx) ** 2 + (y + 0.5 - hit.yPx) ** 2;
          pixels[y * 2560 + x] += (brightness - c.backgroundLevel) * Math.exp(-r2 / (2 * sigma * sigma));
        }
      }
    }
    const y8 = new Uint8Array(pixels.length);
    for (let i = 0; i < pixels.length; i += 1) y8[i] = Math.round(G.clamp(pixels[i], 0, 255));
    return { model: m, stars, y8, project, hash: hash(y8) };
  }
  function sample(y8, u, v, w = 2560, h = 1440) {
    const x = G.clamp(u * w - 0.5, 0, w - 1);
    const y = G.clamp(v * h - 0.5, 0, h - 1);
    const ix = Math.floor(x), iy = Math.floor(y);
    const dx = x - ix, dy = y - iy;
    const a = y8[iy * w + ix], b = y8[iy * w + Math.min(ix + 1, w - 1)];
    const d = y8[Math.min(iy + 1, h - 1) * w + ix];
    const e = y8[Math.min(iy + 1, h - 1) * w + Math.min(ix + 1, w - 1)];
    return (a * (1 - dx) + b * dx) * (1 - dy) + (d * (1 - dx) + e * dx) * dy;
  }
  function buildCameraMap(c) {
    const m = model(c), cam = camera(c), b = basis(c);
    const samples = 4; // 4x4 subpixel quadrature reduces aliasing of small luminous spots.
    const uv = new Float32Array(160 * 120 * samples * samples * 2);
    uv.fill(-1);
    const covered = new Uint8Array(160 * 120);
    let invalidRays = 0;
    let k = 0;
    for (let y = 0; y < 120; y += 1) {
      for (let x = 0; x < 160; x += 1) {
        for (let sy = 0; sy < samples; sy += 1) {
          for (let sx = 0; sx < samples; sx += 1) {
            const ray = G.cameraPixelRay(x + (sx + 0.5) / samples, y + (sy + 0.5) / samples, cam, b);
            if (!ray) invalidRays += 1;
            const hit = ray ? G.intersectCylindricalScreen(ray, m) : null;
            if (hit) {
              uv[k] = hit.u; uv[k + 1] = hit.v;
              covered[y * 160 + x] = 1;
            }
            k += 2;
          }
        }
      }
    }
    return { uv, covered, samples, invalidRays };
  }
  function blur(pixels, sigma) {
    if (sigma <= 0) return pixels;
    const radius = Math.ceil(3 * sigma);
    const kernel = Array.from({ length: 2 * radius + 1 }, (_, i) => Math.exp(-((i - radius) ** 2) / (2 * sigma * sigma)));
    const sum = kernel.reduce((a, b) => a + b, 0);
    const horizontal = new Float32Array(pixels.length), result = new Float32Array(pixels.length);
    for (let y = 0; y < 120; y += 1) for (let x = 0; x < 160; x += 1) {
      for (let k = -radius; k <= radius; k += 1) {
        horizontal[y * 160 + x] += pixels[y * 160 + G.clamp(x + k, 0, 159)] * kernel[k + radius] / sum;
      }
    }
    for (let y = 0; y < 120; y += 1) for (let x = 0; x < 160; x += 1) {
      for (let k = -radius; k <= radius; k += 1) {
        result[y * 160 + x] += horizontal[G.clamp(y + k, 0, 119) * 160 + x] * kernel[k + radius] / sum;
      }
    }
    return result;
  }
  function renderCamera(scene, c, map = buildCameraMap(c)) {
    const frame = new Float32Array(160 * 120);
    const samplesPerPixel = map.samples ** 2;
    for (let pixel = 0; pixel < frame.length; pixel += 1) {
      let sum = 0;
      for (let s = 0; s < samplesPerPixel; s += 1) {
        const index = (pixel * samplesPerPixel + s) * 2;
        if (map.uv[index] >= 0) sum += sample(scene.y8, map.uv[index], map.uv[index + 1]);
      }
      frame[pixel] = sum / samplesPerPixel;
    }
    const y8 = Uint8Array.from(blur(frame, c.cameraPsfSigma), (v) => Math.round(G.clamp(v, 0, 255)));
    const cam = camera(c), b = basis(c);
    const starCount = scene.stars.filter((star) => {
      const ray = G.screenPointToRay(star.point, c.cameraDistanceCm * 10);
      return G.projectMonitorRayToCamera(ray, cam, b)?.inside;
    }).length;
    return { y8, starCount, hash: hash(y8), coverage: map.covered.reduce((a, b) => a + b, 0) / frame.length,
      invalidRays: map.invalidRays };
  }
  function hash(bytes) {
    let h = 2166136261;
    for (const byte of bytes) h = Math.imul(h ^ byte, 16777619);
    return (h >>> 0).toString(16).padStart(8, "0");
  }
  function compensationValid(c) {
    const cam = camera(c), b = basis(c);
    for (let y = 0; y <= 120; y += 15) for (let x = 0; x <= 160; x += 20) {
      if (!G.cameraPixelRay(x, y, cam, b)) return false;
    }
    return true;
  }
  const api = Object.freeze({ defaults, limits, sanitize, snapshot, migrate, model, camera, basis, level,
    sceneKey, projector, buildScene, buildCameraMap, renderCamera, hash, compensationValid });
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  root.StarSimulatorEngine = api;
}(typeof globalThis !== "undefined" ? globalThis : this));
