import { createHash } from "node:crypto";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const revision = "92df9e4c48c7a3b21d4b0cfc6ce088dd8ce2f2df";
const base = "https://raw.githubusercontent.com/Stellarium/stellarium-skycultures/" + revision + "/western/";
const output = new URL("../data/", import.meta.url);
const cache = new URL("../../sim_build/catalog_cache/constellations/", import.meta.url);
await mkdir(fileURLToPath(cache), { recursive: true });
async function source(name) {
  const url = base + name;
  const path = new URL(name, cache);
  let bytes;
  try { bytes = await readFile(path); }
  catch {
    const response = await fetch(url);
    if (!response.ok) throw new Error(url + ": HTTP " + response.status);
    bytes = Buffer.from(await response.arrayBuffer());
    await writeFile(path, bytes);
  }
  return { bytes, url, sha256: createHash("sha256").update(bytes).digest("hex").toUpperCase() };
}
const index = await source("index.json");
const license = await source("description.md");
if (!license.bytes.toString().includes("Text and data: CC BY-SA")) throw new Error("Revisar licencia del origen");
const sourceData = JSON.parse(index.bytes.toString("utf8"));
const catalogText = await readFile(new URL("hipparcos_vmag_le_7.js", output), "utf8");
const catalog = JSON.parse(catalogText.slice(catalogText.indexOf("window.HIPPARCOS_CATALOG=") + 25).trim().replace(/;$/, ""));
const known = new Set(catalog.stars.map((s) => s[0]));
const groups = new Map();
for (const item of sourceData.constellations) {
  if (!item.iau || !Array.isArray(item.lines)) throw new Error("Constelación sin código o líneas");
  const previous = groups.get(item.iau) || { iau: item.iau, name: item.common_name.native || item.common_name.english, lines: [] };
  previous.lines.push(...item.lines.map((line) => {
    const hips = line[0] === "thin" ? line.slice(1) : line;
    if (hips.length < 2 || hips.some((hip) => !Number.isInteger(hip))) throw new Error("Polilínea desconocida");
    return hips;
  }));
  groups.set(item.iau, previous);
}
const constellations = [...groups.values()].sort((a, b) => a.iau.localeCompare(b.iau));
if (constellations.length !== 88) throw new Error("Esperadas 88 constelaciones, encontradas " + constellations.length);
const missing = [...new Set(constellations.flatMap((item) => item.lines.flat()).filter((hip) => !known.has(hip)))];
if (missing.length) throw new Error("Estrellas HIP ausentes: " + missing.join(", "));
const metadata = {
  source_url: index.url, revision, source_sha256: index.sha256,
  license: "CC BY-SA (version unspecified by upstream)", credit: "Stellarium's team",
  license_source: license.url, license_source_sha256: license.sha256,
  adaptation: "HIP polylines, IAU abbreviations and names; illustrations omitted; Serpens parts grouped; thin style normalized.",
  constellation_count: constellations.length,
};
await writeFile(new URL("constellations.js", output),
  "// Derived from Stellarium Western sky culture; CC BY-SA. See CONSTELLATIONS_LICENSE.md.\nwindow.CONSTELLATIONS=" +
  JSON.stringify({ metadata, constellations }) + ";\n");
await writeFile(new URL("CONSTELLATIONS_LICENSE.md", output),
  "# Constellation data attribution\n\nSource: " + index.url +
  "\n\nRevision: " + revision + "\n\nSHA-256 (original index.json): " + index.sha256 +
  "\n\nCredit: Stellarium's team.\n\nLicense statement from the upstream western/description.md:\n\n> Text and data: CC BY-SA\n\n" +
  "The upstream statement does not specify a version. This derived data retains CC BY-SA and its attribution. " +
  "No illustrations or Stellarium rendering code are included. Only HIP polylines, IAU abbreviations and names are extracted; " +
  "Serpens components are grouped. All geometry and rendering code in this simulator is independent.\n\n" +
  "License statement source: " + license.url + "\nSHA-256: " + license.sha256 + "\n");
console.log("PASS build_constellations: " + constellations.length + " constellations; all HIP references resolved");
console.log("Source SHA-256: " + index.sha256);
