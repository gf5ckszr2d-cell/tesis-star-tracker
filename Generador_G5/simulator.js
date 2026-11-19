(function startSimulator() {
  "use strict";
  const E = window.StarSimulatorEngine, G = window.StarGeometry;
  const fixed = window.StarTrackerFixedScene;
  const rotating = window.StarTrackerRotatingScene;
  const catalog = window.HIPPARCOS_CATALOG;
  const figures = window.CONSTELLATIONS;
  const byHip = new Map(catalog.stars.map((s) => [s[0], s]));
  const get = (id) => document.getElementById(id);
  const screenCanvas = get("screenCanvas"), guideCanvas = get("guideCanvas"), cameraCanvas = get("cameraPreview");
  const sectorCanvas = get("sectorPreview");
  const screenContext = screenCanvas.getContext("2d", { alpha: false });
  const guideContext = guideCanvas.getContext("2d");
  const cameraContext = cameraCanvas.getContext("2d", { alpha: false });
  const sceneCanvas = document.createElement("canvas");
  sceneCanvas.width = 2560; sceneCanvas.height = 1440;
  const sceneContext = sceneCanvas.getContext("2d", { alpha: false });
  const storageKey = "star-tracker-g5-rotating-sky-v1";
  let configuration;
  let scene, map, frame, cachedSceneKey = "", cachedMapKey = "", cachedFrameKey = "";
  let renderRequest = 0, saveTimer = 0, panelVisible = true, paintedKey = "";
  let overview = false, overviewKey = "";
  let linePaths = [], constellationLabels = [];
  const fields = [
    ["poseControls", "skyYaw", "Cielo · giro horizontal", "°", true],
    ["poseControls", "skyPitch", "Cielo · giro vertical", "°", true],
    ["poseControls", "skyRotationRoll", "Cielo · giro sobre la vista", "°", true],
    ["modelControls", "cameraDistanceCm", "Distancia de cámara", "cm", false],
    ["modelControls", "horizontalFov", "FOV horizontal", "°", false],
    ["modelControls", "lensK1", "Distorsión k1", "", false],
    ["modelControls", "lensK2", "Distorsión k2", "", false],
    ["modelControls", "starRadiusPx", "Radio de fuente", "px G5", false],
    ["modelControls", "starClarity", "Claridad sintética", "%", false],
  ];
  const checkboxIds = fixed.guideIds;
  const poseIds = rotating.angleIds;
  function makeControls() {
    for (const [parent, id, label, unit, range] of fields) {
      const [min, max, step] = rotating.limits[id];
      const wrap = document.createElement("div");
      wrap.className = range ? "range-field" : "field";
      const heading = document.createElement("div");
      heading.className = "range-heading";
      const caption = document.createElement("label");
      caption.htmlFor = id; caption.textContent = label;
      heading.append(caption);
      const editor = document.createElement("span");
      editor.className = "value-editor";
      const number = document.createElement("input");
      Object.assign(number, { id, type: "number", min, max, step, inputMode: "decimal" });
      number.setAttribute("aria-label", label);
      editor.append(number);
      const units = document.createElement("span");
      units.textContent = unit; editor.append(units);
      if (range) { heading.append(editor); wrap.append(heading); }
      else { wrap.append(caption, editor); }
      if (range) {
        const slider = document.createElement("input");
        Object.assign(slider, { id: id + "Range", type: "range", min, max, step });
        slider.setAttribute("aria-label", label + " (barra)");
        slider.addEventListener("input", () => updateNumber(id, Number(slider.value)));
        wrap.append(slider);
      }
      // Allow temporary '-' or blank while typing; commit only finite non-empty values.
      number.addEventListener("input", () => {
        if (number.value !== "" && Number.isFinite(number.valueAsNumber)) updateNumber(id, number.valueAsNumber, false);
      });
      number.addEventListener("blur", () => syncControls());
      number.addEventListener("keydown", (event) => {
        if (event.key === "Enter") { event.preventDefault(); syncControls(); number.blur(); }
      });
      get(parent).append(wrap);
    }
  }
  function load() {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved) return rotating.configuration(JSON.parse(saved));
    } catch (_error) { /* file:// browsers can refuse storage; controls still work. */ }
    return rotating.configuration();
  }
  function save() {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(persistNow, 180);
  }
  function persistNow() {
    clearTimeout(saveTimer);
    try {
      const stored = Object.fromEntries([...rotating.parameterIds, ...poseIds, ...checkboxIds].map((id) => [id, configuration[id]]));
      localStorage.setItem(storageKey, JSON.stringify(stored));
    }
    catch (_error) { /* Scene remains usable without persistent storage. */ }
  }
  function syncControls(skipId = "") {
    for (const [, id] of fields) {
      if (id !== skipId) get(id).value = configuration[id];
      if (get(id + "Range")) get(id + "Range").value = configuration[id];
    }
    for (const id of checkboxIds) get(id).checked = configuration[id];
  }
  function updateNumber(id, value, commit = true) {
    if (overview) { syncControls(); return; }
    configuration = rotating.configuration({ ...configuration, [id]: value });
    syncControls(commit ? "" : id);
    save(); schedule();
  }
  function putY8(context, y8, width, height) {
    const rgba = context.createImageData(width, height);
    for (let p = 0; p < y8.length; p += 1) {
      rgba.data[p * 4] = y8[p]; rgba.data[p * 4 + 1] = y8[p]; rgba.data[p * 4 + 2] = y8[p];
      rgba.data[p * 4 + 3] = 255;
    }
    context.putImageData(rgba, 0, 0);
  }
  function buildConstellationGuides() {
    linePaths = []; constellationLabels = [];
    for (const item of figures.constellations) {
      let hasVisibleLine = false;
      const anchors = [];
      for (const line of item.lines) {
        for (let i = 1; i < line.length; i += 1) {
          const a = byHip.get(line[i - 1]), b = byHip.get(line[i]);
          // Do not draw a guide to a star deliberately hidden by the magnitude filter.
          if (!a || !b || a[3] > configuration.magnitudeLimit || b[3] > configuration.magnitudeLimit) continue;
          const av = G.celestialUnitVector(a[1], a[2]), bv = G.celestialUnitVector(b[1], b[2]);
          const path = [];
          let previous = null;
          for (let step = 0; step <= 64; step += 1) {
            const t = step / 64;
            const v = G.normalize(av.map((n, axis) => n * (1 - t) + bv[axis] * t));
            const ra = (G.radToDeg(Math.atan2(v[1], v[0])) + 360) % 360;
            const dec = G.radToDeg(Math.asin(v[2]));
            const point = scene.project(ra, dec);
            if (point) {
              if (previous) { path.push([previous.xPx, previous.yPx, point.xPx, point.yPx]); hasVisibleLine = true; }
              anchors.push([point.xPx, point.yPx]);
            }
            previous = point;
          }
          if (path.length) linePaths.push(path);
        }
      }
      if (hasVisibleLine && anchors.length) {
        const x = anchors.reduce((sum, p) => sum + p[0], 0) / anchors.length;
        const y = anchors.reduce((sum, p) => sum + p[1], 0) / anchors.length;
        constellationLabels.push({ text: item.name, x, y });
      }
    }
  }
  function drawGuides() {
    guideContext.clearRect(0, 0, 2560, 1440);
    guideCanvas.hidden = !panelVisible;
    if (guideCanvas.hidden) return;
    guideContext.save();
    if (configuration.showConstellationLines) {
      guideContext.strokeStyle = "rgba(90,190,205,0.65)";
      guideContext.lineWidth = 1.6; guideContext.beginPath();
      for (const path of linePaths) for (const [x1, y1, x2, y2] of path) {
        guideContext.moveTo(x1, y1); guideContext.lineTo(x2, y2);
      }
      guideContext.stroke();
    }
    if (configuration.showConstellationNames) {
      guideContext.font = "20px system-ui"; guideContext.textAlign = "center";
      guideContext.fillStyle = "rgb(135,211,220)";
      const boxes = [];
      for (const item of constellationLabels) {
        const width = guideContext.measureText(item.text).width + 12;
        const x = G.clamp(item.x, width / 2, 2560 - width / 2);
        const y = G.clamp(item.y - 20, 25, 1415);
        if (boxes.some((box) => Math.abs(x - box.x) < (width + box.w) / 2 && Math.abs(y - box.y) < 26)) continue;
        guideContext.fillText(item.text, x, y); boxes.push({ x, y, w: width });
      }
    }
    if (configuration.showLabels) {
      guideContext.font = "16px ui-monospace, monospace"; guideContext.textAlign = "left";
      guideContext.fillStyle = "rgb(180,218,239)";
      for (const star of scene.stars) if (star.magnitude <= 4.5) {
        guideContext.fillText("HIP " + star.hip, star.xPx + 8, star.yPx - 8);
      }
    }
    if (configuration.showFovGuide) {
      guideContext.strokeStyle = "rgb(95,216,255)"; guideContext.lineWidth = 2;
      guideContext.setLineDash([10, 8]); guideContext.beginPath();
      let previous = false;
      for (const hit of G.cameraFovBoundary(E.camera(configuration), E.basis(configuration), E.model(configuration), 100)) {
        if (!hit) { previous = false; continue; }
        if (previous) guideContext.lineTo(hit.xPx, hit.yPx);
        else guideContext.moveTo(hit.xPx, hit.yPx);
        previous = true;
      }
      guideContext.stroke();
    }
    guideContext.restore();
  }
  function qualityStatus() {
    const rect = screenCanvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const w = Math.round(rect.width * dpr), h = Math.round(rect.height * dpr);
    const match = w === 2560 && h === 1440 && Boolean(document.fullscreenElement);
    get("qualityStatus").textContent = "Patrón: 2560 × 1440 · salida estimada: " + w + " × " + h +
      (match ? ". Correspondencia 1:1 estimada; confirma con el monitor." :
        ". Vista de configuración reescalada: usa el G5 en QHD y pantalla completa para capturar.");
  }
  function render() {
    renderRequest = 0;
    const key = rotating.key(configuration);
    if (key !== cachedSceneKey) {
      scene = rotating.build(configuration, catalog.stars);
      putY8(sceneContext, scene.y8, 2560, 1440);
      buildConstellationGuides();
      cachedSceneKey = key;
    }
    const mapKey = JSON.stringify([E.model(configuration), E.snapshot(configuration)]);
    if (mapKey !== cachedMapKey) {
      map = E.buildCameraMap(configuration); cachedMapKey = mapKey;
    }
    const frameKey = key + mapKey + configuration.cameraPsfSigma;
    if (frameKey !== cachedFrameKey) {
      frame = E.renderCamera(scene, configuration, map);
      putY8(cameraContext, frame.y8, 160, 120);
      cachedFrameKey = frameKey;
      cameraCanvas.dataset.frameHash = frame.hash;
    }
    if (key !== paintedKey) {
      screenContext.imageSmoothingEnabled = false;
      screenContext.drawImage(sceneCanvas, 0, 0);
      paintedKey = key;
      screenCanvas.dataset.sceneHash = scene.hash;
    }
    drawGuides();
    const coverage = G.screenAngularCoverage(E.model(configuration));
    get("screenCoverage").textContent = coverage.horizontalDeg.toFixed(1) + "° H × " + coverage.verticalDeg.toFixed(1) + "° V";
    get("verticalFov").textContent = G.cameraVerticalFov(configuration.horizontalFov, 160, 120).toFixed(2) + "°";
    const idealCamera = { ...E.camera(configuration), lensK1: 0, lensK2: 0 };
    const footprint = G.cameraFootprint(idealCamera, E.basis(configuration), E.model(configuration));
    get("fovFootprint").textContent = footprint && !footprint.clipped ?
      (footprint.widthMm / 10).toFixed(1) + " × " + (footprint.heightMm / 10).toFixed(1) + " cm" :
      frame.coverage > 0 ? "Recortada por el panel" : "Fuera del panel";
    get("screenStarCount").textContent = scene.stars.length;
    get("cameraStarCount").textContent = frame.starCount;
    get("constellationCount").textContent = constellationLabels.length;
    cameraCanvas.hidden = overview;
    sectorCanvas.hidden = !overview;
    get("previewTitle").textContent = overview ? "Vista general del sector" : "Vista estimada OV7670";
    get("previewFormat").textContent = overview ? "Sector completo · 16:9" : "160 × 120 · Y8";
    get("overviewButton").textContent = overview ? "Volver a vista de cámara" : "Ver sector completo";
    get("overviewButton").setAttribute("aria-pressed", String(overview));
    get("previewHint").textContent = overview ?
      "Vista de consulta: muestra todo el patrón, sin recorte ni guías. Los giros y parámetros están bloqueados; vuelve a la vista de cámara para mover el cielo." :
      "Modelo geométrico con PSF provisional; no es una captura real. Fuera del panel se representa negro. Las guías nunca entran en esta vista.";
    if (overview && key !== overviewKey) {
      sectorCanvas.getContext("2d", { alpha: false }).drawImage(sceneCanvas, 0, 0);
      sectorCanvas.dataset.sceneHash = scene.hash;
      overviewKey = key;
    }
    get("previewMeta").textContent = overview ?
      "Todo el sector · " + scene.stars.length + " fuentes HIP · Estado " + scene.stateId :
      "Panel dentro de la captura: " + (frame.coverage * 100).toFixed(1) + "%" +
      (frame.invalidRays ? " · k1/k2 producen rayos sin solución: revisa calibración." : "") +
      " · Estado " + scene.stateId + " · Frame " + frame.hash;
    qualityStatus();
  }
  function schedule() {
    if (!renderRequest) renderRequest = requestAnimationFrame(render);
  }
  function setPanelVisible(visible) {
    panelVisible = visible;
    get("controlPanel").hidden = !visible;
    guideCanvas.hidden = !visible;
    if (!visible && document.activeElement instanceof HTMLElement) document.activeElement.blur();
    drawGuides();
  }
  async function fullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch (_error) {
      get("qualityStatus").textContent = "El navegador no permitió pantalla completa. Usa su opción de pantalla completa en el G5.";
      return;
    }
    qualityStatus();
  }
  makeControls();
  configuration = load();
  syncControls();
  for (const id of checkboxIds) get(id).addEventListener("change", () => {
    configuration[id] = get(id).checked; save(); schedule();
  });
  get("closePanelButton").addEventListener("click", () => setPanelVisible(false));
  get("fullscreenButton").addEventListener("click", fullscreen);
  get("overviewButton").addEventListener("click", () => {
    overview = !overview;
    for (const [, id] of fields) {
      get(id).disabled = overview;
      if (get(id + "Range")) get(id + "Range").disabled = overview;
    }
    get("resetButton").disabled = overview;
    render();
  });
  get("resetButton").addEventListener("click", () => {
    if (overview) return;
    configuration = rotating.configuration({ ...configuration, skyYaw: 0, skyPitch: 0, skyRotationRoll: 0 });
    syncControls(); save(); schedule();
  });
  get("exportButton").addEventListener("click", () => {
    render(); // Flush pending controls before exporting the state actually painted.
    const payload = { ...rotating.manifest(scene, frame, catalog.metadata), exported_at_utc: new Date().toISOString() };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url;
    a.download = scene.stateId + ".json";
    a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  get("exportCsvButton").addEventListener("click", () => {
    render();
    const url = URL.createObjectURL(new Blob([rotating.csv(scene)], { type: "text/csv" }));
    const a = document.createElement("a"); a.href = url; a.download = scene.stateId + ".csv";
    a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  get("exportPngButton").addEventListener("click", () => {
    render();
    const name = scene.stateId + ".png";
    sceneCanvas.toBlob(blob => {
      if (!blob) return;
      const url = URL.createObjectURL(blob), a = document.createElement("a");
      a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
    }, "image/png");
  });
  document.addEventListener("keydown", (event) => {
    if (event.ctrlKey || event.metaKey || event.altKey || event.repeat) return;
    if (event.key.toLowerCase() === "m") { event.preventDefault(); setPanelVisible(!panelVisible); }
    else if (event.key.toLowerCase() === "f") { event.preventDefault(); fullscreen(); }
  });
  window.addEventListener("resize", qualityStatus);
  window.addEventListener("pagehide", persistNow);
  document.addEventListener("fullscreenchange", qualityStatus);
  render();
}());
