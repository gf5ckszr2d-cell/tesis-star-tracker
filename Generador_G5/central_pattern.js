(function (root) {
  "use strict";
  const S = typeof module !== "undefined" && module.exports ? require("./synthetic_pattern.js") : root.SyntheticPattern;
  const configuration = Object.freeze({ widthMm: 596.736, heightMm: 335.664, radiusMm: 1000,
    distanceMm: 250, imageWidth: 320, imageHeight: 240, horizontalFovDeg: 25 });
  const fx = configuration.imageWidth / (2 * Math.tan(configuration.horizontalFovDeg * Math.PI / 360));
  const cx = (configuration.imageWidth - 1) / 2, cy = (configuration.imageHeight - 1) / 2;
  const verticalFovDeg = 2 * Math.atan(configuration.imageHeight / (2 * fx)) * 180 / Math.PI;
  function toPanel(u, v) {
    const a = (u - cx) / fx, b = (v - cy) / fx;
    const r = configuration.radiusMm, d = configuration.distanceMm, t = r - d;
    const z = (-t + Math.sqrt(r * r * (1 + a * a) - a * a * t * t)) / (1 + a * a);
    const alpha = Math.atan2(a * z, z - d + r);
    return { x: (alpha * r / configuration.widthMm + 0.5) * S.WIDTH - 0.5,
      y: (b * z / configuration.heightMm + 0.5) * S.HEIGHT - 0.5 };
  }
  function project(star) {
    const sx = configuration.widthMm / S.WIDTH, sy = configuration.heightMm / S.HEIGHT;
    const xMm = (star.x + 0.5) * sx, yMm = (S.HEIGHT - star.y - 0.5) * sy;
    const alpha = (xMm - configuration.widthMm / 2) / configuration.radiusMm;
    const X = configuration.radiusMm * Math.sin(alpha), Y = configuration.heightMm / 2 - yMm;
    const Z = configuration.distanceMm - configuration.radiusMm * (1 - Math.cos(alpha));
    const u = cx + fx * X / Z, v = cy + fx * Y / Z;
    return { id: star.id, xMonitorPx: star.x, yMonitorPx: S.HEIGHT - 1 - star.y,
      xMm, yMm, XcameraMm: X, YcameraMm: Y, ZcameraMm: Z,
      xImagePx: u, yImagePx: configuration.imageHeight - 1 - v,
      xScaled256: Math.round(u * 256), yScaled256: Math.round((configuration.imageHeight - 1 - v) * 256),
      inside: u >= -0.5 && u < configuration.imageWidth - 0.5 && v >= -0.5 && v < configuration.imageHeight - 0.5 };
  }
  function build() {
    const original = S.build(), removed = new Set(["P20", "P21", "P22", "P27", "P28", "P29", "P30", "P38"]);
    let state = original.settings.seed >>> 0;
    function next() {
      state = (state + 0x6D2B79F5) >>> 0;
      let t = Math.imul(state ^ state >>> 15, 1 | state);
      t ^= t + Math.imul(t ^ t >>> 7, 61 | t);
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    }
    const stars = [];
    for (let row = 0; row < 2; row++) for (let col = 0; col < 4; col++) {
      const u = 24 + (col + 0.25 + next() * 0.5) * 68;
      const v = 24 + (row + 0.25 + next() * 0.5) * 96;
      const p = toPanel(u, v);
      stars.push({ id: `P${String(stars.length + 1).padStart(2, "0")}`, x: Math.round(p.x), y: Math.round(p.y) });
    }
    for (const s of original.stars) if (!removed.has(s.id))
      stars.push({ id: `P${String(stars.length + 1).padStart(2, "0")}`, x: s.x, y: s.y });
    return { format: "PATRON_ESTELAR_CENTRAL_V2", algorithm: "mulberry32-central-eight-v2",
      patternId: "sintetico48-central8-s20261119-d24-l255-v2", width: S.WIDTH, height: S.HEIGHT,
      settings: original.settings, configuration, stars };
  }
  function boundary() {
    const points = [], w = configuration.imageWidth, h = configuration.imageHeight;
    for (let i = 0; i <= 40; i++) points.push(toPanel(-0.5 + i * w / 40, -0.5));
    for (let i = 1; i <= 40; i++) points.push(toPanel(w - 0.5, -0.5 + i * h / 40));
    for (let i = 1; i <= 40; i++) points.push(toPanel(w - 0.5 - i * w / 40, h - 0.5));
    for (let i = 1; i <= 40; i++) points.push(toPanel(-0.5, h - 0.5 - i * h / 40));
    return points;
  }
  function manifest(scene) {
    return { ...scene, camera: { fx, fy: fx, cx, cy, verticalFovDeg },
      coordinateSystem: { sourceRaster: "Top-left pixel indices, X right, Y down", referenceDigital: "Lower-left pixel center, X right, Y up", physical: "Lower-left luminous panel edge, X follows arc, Y up" },
      fov: { pose: "centered_aligned", expectedCenters: 8, status: "NOMINAL_UNCALIBRATED" },
      reference: scene.stars.map(project) };
  }
  function csv(scene) {
    const rows = scene.stars.map(project), keys = Object.keys(rows[0]);
    return keys.join(",") + "\n" + rows.map(r => keys.map(k => r[k]).join(",")).join("\n") + "\n";
  }
  const api = { configuration, fx, cx, cy, verticalFovDeg, toPanel, project, build, boundary, manifest, csv };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  root.CentralPattern = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
