(function () {
  "use strict";
  const S = window.SyntheticPattern, G = window.CentralPattern;
  const $ = id => document.getElementById(id);
  const scene = G.build(), pixels = S.raster(scene);
  const canvas = $("pattern"), ctx = canvas.getContext("2d"), rgba = ctx.createImageData(S.WIDTH, S.HEIGHT);
  for (let i = 0; i < pixels.length; i++) {
    const j = i * 4;
    rgba.data[j] = rgba.data[j + 1] = rgba.data[j + 2] = pixels[i]; rgba.data[j + 3] = 255;
  }
  ctx.putImageData(rgba, 0, 0);
  const g = $("guides").getContext("2d"), boundary = G.boundary();
  g.strokeStyle = "#82c7b7"; g.lineWidth = 3; g.beginPath();
  boundary.forEach((p, i) => i ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y));
  g.closePath(); g.stroke();
  g.font = "22px monospace"; g.fillStyle = "#b9ccda";
  for (const star of scene.stars) g.fillText(star.id, star.x + 18, star.y - 14);
  const list = scene.stars.map(G.project).filter(s => s.inside);
  $("count").textContent = list.length;
  $("visibleIds").textContent = list.map(s => s.id).join(" · ");
  $("patternId").textContent = scene.patternId;
  $("status").textContent = "Patrón y FOV fijos. Ocho centros en la vista central nominal.";
  const preview = $("preview"), p = preview.getContext("2d"), image = p.createImageData(preview.width, preview.height);
  function sample(x, y) {
    const ix = Math.floor(x), iy = Math.floor(y), dx = x - ix, dy = y - iy;
    const at = (a, b) => a < 0 || b < 0 || a >= S.WIDTH || b >= S.HEIGHT ? 0 : pixels[b * S.WIDTH + a];
    return Math.round(at(ix, iy) * (1-dx) * (1-dy) + at(ix+1, iy) * dx * (1-dy)
      + at(ix, iy+1) * (1-dx) * dy + at(ix+1, iy+1) * dx * dy);
  }
  for (let y = 0; y < preview.height; y++) for (let x = 0; x < preview.width; x++) {
    const q = G.toPanel(x, y), level = sample(q.x, q.y), j = (y * preview.width + x) * 4;
    image.data[j] = image.data[j+1] = image.data[j+2] = level; image.data[j+3] = 255;
  }
  p.putImageData(image, 0, 0);
  function download(blob, suffix) {
    const url = URL.createObjectURL(blob), link = document.createElement("a");
    link.href = url; link.download = scene.patternId + suffix; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
  }
  async function present() {
    document.body.classList.add("presenting");
    try { if (!document.fullscreenElement) await $("stage").requestFullscreen(); }
    catch { $("status").textContent = "Presentación activa. F11 oculta la barra del navegador; Esc vuelve a los controles."; }
  }
  function leave() {
    document.body.classList.remove("presenting");
    if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
  }
  document.addEventListener("fullscreenchange", () => {
    if (!document.fullscreenElement) document.body.classList.remove("presenting");
  });
  $("present").addEventListener("click", present);
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") { leave(); return; }
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key.toLowerCase() === "f") {
      e.preventDefault();
      if (document.body.classList.contains("presenting")) leave(); else present();
    }
  });
  $("png").addEventListener("click", () => canvas.toBlob(blob => {
    if (blob) download(blob, ".png");
  }, "image/png"));
  $("json").addEventListener("click", () => download(new Blob([JSON.stringify(G.manifest(scene), null, 2) + "\n"], { type: "application/json" }), ".json"));
  $("csv").addEventListener("click", () => download(new Blob([G.csv(scene)], { type: "text/csv;charset=utf-8" }), ".csv"));
})();
