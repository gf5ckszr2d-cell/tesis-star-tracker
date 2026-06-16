from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from star_calibration_lib import save_json


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Genera un patron estelar sintetico para mostrar en pantalla.")
    parser.add_argument("--width", type=int, default=2160, help="Ancho de la pantalla/patron. Default: 2160")
    parser.add_argument("--height", type=int, default=1440, help="Alto de la pantalla/patron. Default: 1440")
    parser.add_argument("--stars", type=int, default=12, help="Cantidad de estrellas. Default: 12")
    parser.add_argument("--seed", type=int, default=2026, help="Semilla reproducible. Default: 2026")
    parser.add_argument("--radius", type=int, default=7, help="Radio base de cada estrella en pixeles de pantalla")
    parser.add_argument("--margin", type=int, default=120, help="Margen para no generar estrellas en el borde")
    parser.add_argument("--output-dir", default="patrones", help="Carpeta de salida. Default: patrones")
    parser.add_argument("--stem", default="star_pattern", help="Nombre base de salida")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    rng = random.Random(args.seed)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    image = Image.new("L", (args.width, args.height), 0)
    draw = ImageDraw.Draw(image)

    stars = []
    for star_id in range(args.stars):
        radius = max(2, args.radius + rng.randint(-2, 2))
        x = rng.randint(args.margin, args.width - args.margin)
        y = rng.randint(args.margin, args.height - args.margin)
        intensity = rng.randint(210, 255)

        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=intensity)
        draw.ellipse((x - max(1, radius // 3), y - max(1, radius // 3), x + max(1, radius // 3), y + max(1, radius // 3)), fill=255)

        stars.append(
            {
                "id": star_id,
                "x": float(x),
                "y": float(y),
                "radius": radius,
                "intensity": intensity,
            }
        )

    png_path = output_dir / f"{args.stem}.png"
    json_path = output_dir / f"{args.stem}.json"
    image.save(png_path)
    save_json(
        {
            "width": args.width,
            "height": args.height,
            "seed": args.seed,
            "stars": stars,
        },
        json_path,
    )

    print(f"Patron generado: {png_path}")
    print(f"Metadata: {json_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
