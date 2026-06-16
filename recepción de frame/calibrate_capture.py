from __future__ import annotations

import argparse
import sys
from pathlib import Path

from star_calibration_lib import (
    detect_stars_from_pixels,
    draw_detections,
    image_stats,
    load_json,
    load_luma_image,
    match_centroids,
    recommendation,
    save_json,
    scale_expected_stars,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Genera un reporte de calibracion para una captura OV7670.")
    parser.add_argument("--expected", required=True, help="JSON del patron generado")
    parser.add_argument("--image", default="capturas/frame_y.png", help="Imagen capturada")
    parser.add_argument("--threshold", type=int, default=45, help="Umbral Y para detectar estrellas")
    parser.add_argument("--min-area", type=int, default=2, help="Area minima del blob")
    parser.add_argument("--max-area", type=int, default=500, help="Area maxima del blob")
    parser.add_argument("--max-error", type=float, default=8.0, help="Error maximo de matching")
    parser.add_argument("--param", default="base", help="Parametro probado: base, contraste, ganancia, exposicion, brillo")
    parser.add_argument("--selector", default="--", help="Selector SW14:SW13 usado, por ejemplo 00")
    parser.add_argument("--value", default="--", help="Valor SW7:SW0 usado, por ejemplo 0x60")
    parser.add_argument("--output-dir", default="capturas/calibracion", help="Carpeta del reporte")
    parser.add_argument("--stem", default="calibration_report", help="Nombre base de salida")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    image, pixels, width, height = load_luma_image(args.image)
    stats = image_stats(pixels)
    detected_stars = detect_stars_from_pixels(pixels, width, height, args.threshold, args.min_area, args.max_area)

    expected = load_json(args.expected)
    expected_scaled = scale_expected_stars(expected, width, height)
    comparison = match_centroids(expected_scaled, detected_stars, args.max_error)

    report = {
        "parameter": {
            "name": args.param,
            "selector_sw14_sw13": args.selector,
            "value_sw7_sw0": args.value,
        },
        "input": {
            "expected": args.expected,
            "image": args.image,
            "width": width,
            "height": height,
        },
        "detection": {
            "threshold": args.threshold,
            "min_area": args.min_area,
            "max_area": args.max_area,
            "stats": stats,
            "stars": detected_stars,
        },
        "comparison": comparison,
        "recommendation": recommendation(stats, comparison),
    }

    json_path = save_json(report, output_dir / f"{args.stem}.json")
    overlay_path = draw_detections(image, detected_stars, output_dir / f"{args.stem}_overlay.png")

    mean_error = comparison["mean_error_px"]
    max_error = comparison["max_error_px"]

    print(f"Parametro: {args.param}, selector={args.selector}, value={args.value}")
    print(f"Detectadas: {len(detected_stars)} / Esperadas: {len(expected_scaled)}")
    print(f"Perdidas: {comparison['missed_count']}, Falsas: {comparison['false_count']}")
    print(f"Error medio: {mean_error:.3f} px" if mean_error is not None else "Error medio: N/A")
    print(f"Error maximo: {max_error:.3f} px" if max_error is not None else "Error maximo: N/A")
    print(f"max_y={stats['max_y']:.1f}, mean_y={stats['mean_y']:.2f}, saturated={stats['saturated_pct']:.3f}%")
    print(f"Diagnostico: {report['recommendation']}")
    print(f"Reporte: {json_path}")
    print(f"Overlay: {overlay_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
