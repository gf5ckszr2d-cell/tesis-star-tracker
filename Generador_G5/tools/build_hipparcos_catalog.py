from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from datetime import UTC, datetime
from pathlib import Path


CATALOG_URL = (
    "https://heasarc.gsfc.nasa.gov/xamin/query?"
    "table=hipparcos&fields=hip_number,ra_deg,dec_deg,vmag&"
    "constraint=vmag%3C%3D7&format=stream&resultmax=200000"
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Descarga Hipparcos I/239 y genera el subconjunto usado por el simulador G5."
    )
    parser.add_argument("--magnitude-limit", type=float, default=7.0)
    parser.add_argument(
        "--cache",
        type=Path,
        default=Path("sim_build/catalog_cache/hipparcos_vmag_le_7.stream"),
        help="Respuesta local de NASA HEASARC con las columnas usadas.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("Simulador_cielo_G5/data/hipparcos_vmag_le_7.js"),
    )
    parser.add_argument("--force-download", action="store_true")
    return parser


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def download_catalog(destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    request = urllib.request.Request(
        CATALOG_URL,
        headers={"User-Agent": "tesis-star-tracker-catalog-builder/1.0"},
    )
    print(f"Descargando {CATALOG_URL}")
    with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    temporary.replace(destination)


def parse_catalog(source: Path, magnitude_limit: float) -> list[list[float | int]]:
    stars: list[list[float | int]] = []
    with source.open("rt", encoding="ascii", errors="strict") as stream:
        header = stream.readline().strip().split("|")
        if header != ["hip_number", "ra_deg", "dec_deg", "vmag"]:
            raise ValueError(f"Cabecera HEASARC inesperada: {header}")
        for line_number, line in enumerate(stream, start=2):
            if not line.strip():
                continue
            fields = line.rstrip("\n").split("|")
            if len(fields) != 4:
                raise ValueError(f"Registro Hipparcos inválido en línea {line_number}")
            try:
                hip = int(fields[0])
                ra_deg = float(fields[1])
                dec_deg = float(fields[2])
                magnitude = float(fields[3])
            except ValueError:
                continue
            if magnitude <= magnitude_limit:
                stars.append([hip, round(ra_deg, 8), round(dec_deg, 8), round(magnitude, 2)])
    stars.sort(key=lambda item: (item[3], item[0]))
    return stars


def write_javascript(
    destination: Path,
    stars: list[list[float | int]],
    magnitude_limit: float,
    source_sha256: str,
) -> None:
    payload = {
        "metadata": {
            "catalog": "Hipparcos Main Catalogue I/239/hip_main",
            "credit": "ESA (1997), The Hipparcos and Tycho Catalogues",
            "source_url": CATALOG_URL,
            "distribution": "NASA HEASARC Hipparcos table, stream query",
            "source_sha256": source_sha256,
            "upstream_records": 118218,
            "selected_records": len(stars),
            "magnitude_field": "Johnson V (H5)",
            "magnitude_limit": magnitude_limit,
            "coordinates": "ICRS, epoch J1991.25 (H8/H9)",
            "generated_at_utc": datetime.now(UTC).replace(microsecond=0).isoformat(),
            "record_format": ["HIP", "RA_deg", "Dec_deg", "Vmag"],
        },
        "stars": stars,
    }
    destination.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    destination.write_text(
        "// Generado por tools/build_hipparcos_catalog.py; no editar manualmente.\n"
        f"window.HIPPARCOS_CATALOG={encoded};\n",
        encoding="utf-8",
        newline="\n",
    )


def main() -> int:
    args = build_parser().parse_args()
    if not 0 <= args.magnitude_limit <= 7:
        raise ValueError("--magnitude-limit debe estar entre 0 y 7 para esta descarga")
    if args.force_download or not args.cache.exists():
        download_catalog(args.cache)
    source_hash = sha256_file(args.cache)
    stars = parse_catalog(args.cache, args.magnitude_limit)
    if len(stars) < 10_000:
        raise ValueError(f"La consulta parece incompleta: solo produjo {len(stars)} estrellas")
    write_javascript(args.output, stars, args.magnitude_limit, source_hash)
    print(f"Fuente SHA-256: {source_hash}")
    print(f"Estrellas con Vmag <= {args.magnitude_limit:g}: {len(stars)}")
    print(f"Generado: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
