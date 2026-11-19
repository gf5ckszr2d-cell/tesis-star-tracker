(function attach(root) {
  "use strict";
  const node = typeof module !== "undefined" && module.exports;
  const E = node ? require("./engine.js") : root.StarSimulatorEngine;
  const G = node ? require("./geometry.js") : root.StarGeometry;
  const fixed = node ? require("./fixed_scene.js") : root.StarTrackerFixedScene;
  const angleIds = Object.freeze(["skyYaw", "skyPitch", "skyRotationRoll"]);
  const parameterIds = Object.freeze(["cameraDistanceCm", "horizontalFov", "screenWidthMm", "screenHeightMm",
    "curveRadiusMm", "lensK1", "lensK2", "magnitudeLimit", "backgroundLevel", "peakLevel",
    "starClarity", "starRadiusPx", "cameraPsfSigma"]);
  const limits = { ...E.limits, skyYaw: [-75, 75, 0.1], skyPitch: [-75, 75, 0.1], skyRotationRoll: [-180, 180, 0.1] };
  function configuration(raw = {}) {
    const input = { ...fixed.configuration };
    for (const id of [...parameterIds, ...fixed.guideIds]) if (raw[id] !== undefined) input[id] = raw[id];
    // Physical camera orientation is fixed. Legacy camera-pose preferences cannot move it.
    const result = E.sanitize({ ...input, cameraYaw: 0, cameraPitch: 0, cameraRoll: 0 });
    for (const id of angleIds) {
      const value = raw[id] !== "" && raw[id] != null ? Number(raw[id]) : 0;
      result[id] = Number.isFinite(value) ? G.clamp(value, limits[id][0], limits[id][1]) : 0;
    }
    return result;
  }
  const dot = (a, b) => a.reduce((n, v, i) => n + v * b[i], 0);
  function transform(c) {
    const base = G.celestialBasis(c.centerRa, c.centerDec, c.skyRoll);
    const rotation = G.cameraBasis(c.skyYaw, c.skyPitch, c.skyRotationRoll);
    const zero = angleIds.every(id => c[id] === 0);
    return (ra, dec) => {
      const s = G.celestialUnitVector(ra, dec);
      // No hemisphere rejection here: stars behind the initial view may enter after rotation.
      const baseRay = [dot(s, base.right), dot(s, base.up), -dot(s, base.forward)];
      const ray = zero ? baseRay : G.cameraRayToMonitor([baseRay[0], baseRay[1], -baseRay[2]], rotation);
      if (zero) return { ra, dec, baseRay, ray };
      const v = base.right.map((x, i) => x * ray[0] + base.up[i] * ray[1] - base.forward[i] * ray[2]);
      return { ra: (G.radToDeg(Math.atan2(v[1], v[0])) + 360) % 360,
        dec: G.radToDeg(Math.asin(G.clamp(v[2], -1, 1))), baseRay, ray };
    };
  }
  function key(c) {
    return JSON.stringify([...parameterIds, ...angleIds].map(id => c[id]));
  }
  function stateId(c) {
    return "g5r-" + E.hash(Uint8Array.from(key(c), ch => ch.charCodeAt(0)));
  }
  function build(raw, catalog) {
    const c = configuration(raw), rotate = transform(c);
    // Geometric projection only. Lens distortion affects the camera preview, not a second prewarp.
    const reference = E.snapshot({ ...c, lensK1: 0, lensK2: 0 });
    const rotated = catalog.map(([hip, ra, dec, mag]) => {
      const p = rotate(ra, dec); return [hip, p.ra, p.dec, mag];
    });
    const scene = E.buildScene(c, reference, rotated);
    const source = new Map(catalog.map(row => [row[0], row]));
    const projectRotated = scene.project;
    scene.project = (ra, dec) => { const p = rotate(ra, dec); return projectRotated(p.ra, p.dec); };
    for (const star of scene.stars) {
      const [, ra, dec] = source.get(star.hip);
      const p = rotate(ra, dec);
      star.ra = ra; star.dec = dec; star.baseRay = p.baseRay; star.rotatedRay = p.ray;
    }
    scene.configuration = c; scene.reference = reference; scene.stateId = stateId(c);
    return scene;
  }
  function rows(scene) {
    const c = scene.configuration;
    return scene.stars.map(s => ({ hip: s.hip, ra: s.ra, dec: s.dec, magnitude: s.magnitude,
      x: s.xPx, y: s.yPx, baseRay: s.baseRay, rotatedRay: s.rotatedRay,
      panelRay: G.screenPointToRay(s.point, c.cameraDistanceCm * 10) }));
  }
  function csv(scene) {
    const header = "state_id,HIP,RA_deg,Dec_deg,Vmag,screen_x_px,screen_y_px,base_x,base_y,base_z,rotated_x,rotated_y,rotated_z,panel_x,panel_y,panel_z";
    return [header, ...rows(scene).map(s => [scene.stateId, s.hip, s.ra, s.dec, s.magnitude, s.x, s.y,
      ...s.baseRay, ...s.rotatedRay, ...s.panelRay].join(","))].join("\n") + "\n";
  }
  function manifest(scene, frame, catalogMetadata) {
    return { format: "STAR_TRACKER_G5_ROTATING_STATE_V1", status: "SIMULATED_UNCALIBRATED",
      stateId: scene.stateId, baseReference: fixed.name, configuration: scene.configuration,
      cameraFixed: true, projection: "geometric_no_lens_prewarp", catalog: catalogMetadata,
      rotationConvention: "Active rotation in base G5 frame using cameraBasis(yaw,pitch,roll); camera remains at zero pose",
      sceneHashFnv32: scene.hash, frameHashFnv32: frame.hash, starCountOnScreen: scene.stars.length,
      starCountInCamera: frame.starCount, stars: rows(scene) };
  }
  const api = Object.freeze({ configuration, transform, key, stateId, build, rows, csv, manifest,
    angleIds, parameterIds, guideIds: fixed.guideIds, limits });
  if (node) module.exports = api;
  root.StarTrackerRotatingScene = api;
}(typeof globalThis !== "undefined" ? globalThis : this));
