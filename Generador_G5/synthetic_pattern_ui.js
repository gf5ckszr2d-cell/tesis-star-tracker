(function () {
  "use strict";
  const S = window.SyntheticPattern, $ = id => document.getElementById(id);
  const canvas = $("pattern"), guides = $("guides"), preview = $("preview");
  let scene, box;
  function notify(message) { $("status").textContent = message; }
  function updateCropControls() {
    $("cropWidth").value = box.width;
    $("cropWidthValue").textContent = `${box.width} × ${box.height} px`;
    $("cropX").max = S.WIDTH - box.width; $("cropX").value = box.x;
    $("cropY").max = S.HEIGHT - box.height; $("cropY").value = box.y;
  }
  function drawCrop() {
    const g = guides.getContext("2d"), list = S.visible(scene, box);
    g.clearRect(0, 0, S.WIDTH, S.HEIGHT);
    if ($("grid").checked) {
      g.strokeStyle = "#39434b"; g.lineWidth = 1;
      g.beginPath();
      for (let col = 1; col < S.COLS; col++) { g.moveTo(col * 320, 0); g.lineTo(col * 320, S.HEIGHT); }
      for (let row = 1; row < S.ROWS; row++) { g.moveTo(0, row * 240); g.lineTo(S.WIDTH, row * 240); }
      g.stroke();
    }
    g.strokeStyle = "#82c7b7"; g.lineWidth = 3; g.strokeRect(box.x, box.y, box.width, box.height);
    if ($("labels").checked) {
      g.font = "24px monospace"; g.fillStyle = "#b9ccda";
      for (const star of scene.stars) g.fillText(star.id, star.x + 20, star.y - 16);
    }
    const p = preview.getContext("2d");
    p.fillStyle = "#000"; p.fillRect(0, 0, preview.width, preview.height);
    p.imageSmoothingEnabled = true;
    p.drawImage(canvas, box.x, box.y, box.width, box.height, 0, 0, preview.width, preview.height);
    $("count").textContent = list.length;
    $("visibleIds").textContent = list.map(s => s.id).join(" · ") || "Sin centros en este encuadre";
    updateCropControls();
  }
  function generate(resetCrop) {
    scene = S.build({ seed: $("seed").value, diameter: $("diameter").value, level: $("level").value });
    $("seed").value = scene.settings.seed;
    $("diameterValue").textContent = `${scene.settings.diameter} px`;
    $("levelValue").textContent = `${scene.settings.level} / 255`;
    $("patternId").textContent = scene.patternId;
    const pixels = S.raster(scene), ctx = canvas.getContext("2d"), rgba = ctx.createImageData(S.WIDTH, S.HEIGHT);
    for (let i = 0; i < pixels.length; i++) { const j = i * 4; rgba.data[j] = rgba.data[j + 1] = rgba.data[j + 2] = pixels[i]; rgba.data[j + 3] = 255; }
    ctx.putImageData(rgba, 0, 0);
    if (resetCrop || !box) box = S.findEight(scene);
    drawCrop(); notify("Patrón fijo. Se conserva hasta que cambies sus parámetros.");
  }
  function download(blob, suffix) {
    const url = URL.createObjectURL(blob), link = document.createElement("a");
    link.href = url; link.download = scene.patternId + suffix; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
  }
  async function present() {
    document.body.classList.add("presenting");
    try { if (!document.fullscreenElement) await $("stage").requestFullscreen(); }
    catch { notify("Vista de presentación activa. Puedes usar F11 para ocultar la barra del navegador; Esc vuelve a los controles."); }
  }
  function leavePresentation() {
    document.body.classList.remove("presenting");
    if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
  }
  document.addEventListener("fullscreenchange", () => {
    if (!document.fullscreenElement) document.body.classList.remove("presenting");
  });
  $("generate").addEventListener("click", () => generate(true));
  for (const id of ["diameter", "level"]) $(id).addEventListener("input", () => generate(false));
  for (const id of ["grid", "labels"]) $(id).addEventListener("change", drawCrop);
  for (const id of ["cropWidth", "cropX", "cropY"]) $(id).addEventListener("input", () => {
    const width = Number($("cropWidth").value);
    box = S.crop({ width, x: $("cropX").value, y: $("cropY").value }); drawCrop();
  });
  $("eight").addEventListener("click", () => {
    box = S.findEight(scene); drawCrop();
    notify(S.visible(scene, box).length === 8 ? "Encuadre con ocho centros. El patrón permanece igual." : "Esta semilla requiere ajustar el encuadre manualmente.");
  });
  $("present").addEventListener("click", present);
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") { leavePresentation(); return; }
    if (e.target instanceof HTMLInputElement || e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key.toLowerCase() === "f") {
      e.preventDefault();
      if (document.body.classList.contains("presenting")) leavePresentation(); else present();
    }
  });
  $("png").addEventListener("click", () => canvas.toBlob(blob => {
    if (blob) download(blob, ".png"); else notify("No se pudo exportar la imagen.");
  }, "image/png"));
  $("json").addEventListener("click", () => download(new Blob([JSON.stringify(S.manifest(scene, box), null, 2) + "\n"], { type: "application/json" }), ".json"));
  $("csv").addEventListener("click", () => download(new Blob([S.csv(scene, box)], { type: "text/csv;charset=utf-8" }), ".csv"));
  generate(true);
})();
