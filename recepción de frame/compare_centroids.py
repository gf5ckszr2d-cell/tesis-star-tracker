from __future__ import annotations

import argparse
import sys

from star_calibration_lib import load_json, match_centroids, save_json, scale_expected_stars


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Compara centroides esperados contra centroides detectados.")
    parser.add_argument("--expected", required=True, help="JSON del patron generado")
    parser.add_argument("--detected", required=True, help="JSON generado por detect_stars.py")
    parser.add_argument("--max-error", type=float, default=8.0, help="Error maximo de matching en pixeles de captura")
    parser.add_argument("--output-json", default="capturas/centroid_comparison.json", help="JSON de comparacion")
    return parser


def main() -> int:
    args = build_parser().parse_args()

    expected = load_json(args.expected)
    detected = load_json(args.detected)
    expected_scaled = scale_expected_stars(expected, detected["width"], detected["height"])
    comparison = match_centroids(expected_scaled, detected["stars"], args.max_error)

    result = {
        "expected_pattern": args.expected,
        "detected_frame": args.detected,
        "capture_width": detected["width"],
        "capture_height": detected["height"],
        "max_match_error_px": args.max_error,
        "expected_scaled": expected_scaled,
        "comparison": comparison,
    }

    output_path = save_json(result, args.output_json)
    mean_error = comparison["mean_error_px"]
    max_error = comparison["max_error_px"]

    print(f"Esperadas: {len(expected_scaled)}")
    print(f"Detectadas: {len(detected['stars'])}")
    print(f"Matches: {comparison['matched_count']}")
    print(f"Perdidas: {comparison['missed_count']}")
    print(f"Falsas: {comparison['false_count']}")
    print(f"Error medio: {mean_error:.3f} px" if mean_error is not None else "Error medio: N/A")
    print(f"Error maximo: {max_error:.3f} px" if max_error is not None else "Error maximo: N/A")
    print(f"JSON: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
