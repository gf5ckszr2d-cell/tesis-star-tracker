from __future__ import annotations

import argparse
import sys
from pathlib import Path

from star_calibration_lib import (
    detect_stars_from_pixels,
    draw_detections,
    image_stats,
    load_luma_image,
    save_json,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Detecta estrellas y centroides en una imagen Y8/PNG.")
    parser.add_argument("--image", required=True, help="Imagen capturada, por ejemplo capturas/frame_y.png")
    parser.add_argument("--threshold", type=int, default=45, help="Umbral Y para detectar estrellas")
    parser.add_argument("--min-area", type=int, default=2, help="Area minima del blob")
    parser.add_argument("--max-area", type=int, default=500, help="Area maxima del blob")
    parser.add_argument("--output-json", default="capturas/detected_stars.json", help="JSON de salida")
    parser.add_argument("--overlay", default="capturas/detected_stars_overlay.png", help="PNG con detecciones dibujadas")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    image, pixels, width, height = load_luma_image(args.image)
    stats = image_stats(pixels)
    stars = detect_stars_from_pixels(pixels, width, height, args.threshold, args.min_area, args.max_area)

    result = {
        "image": str(Path(args.image)),
        "width": width,
        "height": height,
        "threshold": args.threshold,
        "min_area": args.min_area,
        "max_area": args.max_area,
        "stats": stats,
        "stars": stars,
    }

    json_path = save_json(result, args.output_json)
    overlay_path = draw_detections(image, stars, args.overlay)

    print(f"Estrellas detectadas: {len(stars)}")
    print(f"max_y={stats['max_y']:.1f}, mean_y={stats['mean_y']:.2f}, saturated={stats['saturated_pct']:.3f}%")
    print(f"JSON: {json_path}")
    print(f"Overlay: {overlay_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
