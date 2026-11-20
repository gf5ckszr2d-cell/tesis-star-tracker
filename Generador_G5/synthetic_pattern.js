(function (root) {
  "use strict";
  const WIDTH = 2560, HEIGHT = 1440, COLS = 8, ROWS = 6;
  const defaults = Object.freeze({ seed: 20261119, diameter: 24, level: 255 });
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  function integer(value, fallback, lo, hi) {
    return value !== "" && value != null && Number.isFinite(Number(value))
      ? clamp(Math.round(Number(value)), lo, hi) : fallback;
  }
  function config(raw = {}) {
    return { seed: integer(raw.seed, defaults.seed, 0, 4294967295),
      diameter: integer(raw.diameter, defaults.diameter, 8, 64),
      level: integer(raw.level, defaults.level, 40, 255) };
  }
  function random(seed) {
    let state = seed >>> 0;
    return function () {
      state = (state + 0x6D2B79F5) >>> 0;
      let t = Math.imul(state ^ state >>> 15, 1 | state);
      t ^= t + Math.imul(t ^ t >>> 7, 61 | t);
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  function build(raw) {
    const settings = config(raw), next = random(settings.seed), stars = [];
    for (let row = 0; row < ROWS; row++) for (let col = 0; col < COLS; col++) {
      stars.push({ id: `P${String(stars.length + 1).padStart(2, "0")}`,
        row: row + 1, column: col + 1,
        x: Math.round((col + 0.2 + next() * 0.6) * WIDTH / COLS),
        y: Math.round((row + 0.2 + next() * 0.6) * HEIGHT / ROWS) });
    }
    return { format: "PATRON_ESTELAR_SINTETICO_V1", algorithm: "mulberry32-stratified-v1",
      patternId: `sintetico48-s${settings.seed}-d${settings.diameter}-l${settings.level}`,
      width: WIDTH, height: HEIGHT, columns: COLS, rows: ROWS, settings, stars };
  }
  function crop(raw = {}) {
    const width = integer(raw.width, 1120, 320, 1920), height = width * 3 / 4;
    return { x: clamp(Number(raw.x) || 0, 0, WIDTH - width),
      y: clamp(Number(raw.y) || 0, 0, HEIGHT - height), width, height };
  }
  function visible(scene, box) {
    return scene.stars.filter(s => s.x >= box.x && s.x < box.x + box.width && s.y >= box.y && s.y < box.y + box.height);
  }
  function findEight(scene) {
    // Prefer a central 4:3 crop with clear margins around every source.
    let best = null, bestScore = Infinity;
    for (let width = 800; width <= 1440; width += 16) {
      const height = width * 3 / 4;
      for (let dy = -120; dy <= 120; dy += 40) for (let dx = -160; dx <= 160; dx += 40) {
        const box = crop({ x: (WIDTH - width) / 2 + dx, y: (HEIGHT - height) / 2 + dy, width });
        const inside = visible(scene, box);
        if (inside.length !== 8) continue;
        const edgeDistance = Math.min(...scene.stars.map(s => {
          if (s.x < box.x - 40 || s.x > box.x + width + 40 || s.y < box.y - 40 || s.y > box.y + height + 40) return 1000;
          return Math.min(Math.abs(s.x - box.x), Math.abs(s.x - box.x - width), Math.abs(s.y - box.y), Math.abs(s.y - box.y - height));
        }));
        const score = dx * dx + dy * dy + (width - 1120) ** 2 + Math.max(0, 40 - edgeDistance) ** 2 * 100;
        if (score < bestScore) { best = box; bestScore = score; }
      }
    }
    return best || crop({ x: 720, y: 300, width: 1120 });
  }
  function raster(scene) {
    const pixels = new Uint8Array(WIDTH * HEIGHT), radius = scene.settings.diameter / 2;
    const sigma = radius / 2.5, level = scene.settings.level;
    for (const s of scene.stars) {
      for (let y = Math.ceil(s.y - radius); y <= Math.floor(s.y + radius); y++) {
        for (let x = Math.ceil(s.x - radius); x <= Math.floor(s.x + radius); x++) {
          const r2 = (x - s.x) ** 2 + (y - s.y) ** 2;
          if (r2 <= radius * radius && x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT)
            pixels[y * WIDTH + x] = Math.max(pixels[y * WIDTH + x], Math.round(level * Math.exp(-r2 / (2 * sigma * sigma))));
        }
      }
    }
    return pixels;
  }
  function manifest(scene, box = findEight(scene)) {
    return { ...scene, coordinateSystem: "Monitor pixels; origin top-left; x right; y down; centers at integer pixel indices",
      source: { family: "Identical circular truncated Gaussian", diameterPx: scene.settings.diameter,
        sigmaPx: scene.settings.diameter / 5, peakY8: scene.settings.level, backgroundY8: 0 },
      preview: { ...box, centersInside: visible(scene, box).length,
        meaning: "Digital 4:3 crop only. Not an optical camera model or a physical detection count." },
      status: "SYNTHETIC_UNCALIBRATED" };
  }
  function csv(scene, box = findEight(scene)) {
    return "pattern_id,id,row,column,x_monitor_px,y_monitor_px,diameter_px,sigma_px,peak_y8,in_digital_crop\n" + scene.stars.map(s =>
      [scene.patternId, s.id, s.row, s.column, s.x, s.y, scene.settings.diameter, scene.settings.diameter / 5,
        scene.settings.level, visible({ stars: [s] }, box).length].join(",")).join("\n") + "\n";
  }
  const api = { WIDTH, HEIGHT, COLS, ROWS, defaults, config, build, crop, visible, findEight, raster, manifest, csv };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  root.SyntheticPattern = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
