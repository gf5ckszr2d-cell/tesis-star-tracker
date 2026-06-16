from __future__ import annotations

import json
import math
from collections import deque
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw


def load_luma_image(path: str | Path) -> tuple[Image.Image, list[int], int, int]:
    image = Image.open(path).convert("L")
    width, height = image.size
    pixels = list(image.getdata())
    return image, pixels, width, height


def image_stats(pixels: list[int]) -> dict[str, float]:
    if not pixels:
        return {
            "min_y": 0.0,
            "max_y": 0.0,
            "mean_y": 0.0,
            "std_y": 0.0,
            "saturated_pixels": 0.0,
            "saturated_pct": 0.0,
        }

    count = len(pixels)
    mean = sum(pixels) / count
    variance = sum((value - mean) ** 2 for value in pixels) / count
    saturated = sum(1 for value in pixels if value >= 250)

    return {
        "min_y": float(min(pixels)),
        "max_y": float(max(pixels)),
        "mean_y": mean,
        "std_y": math.sqrt(variance),
        "saturated_pixels": float(saturated),
        "saturated_pct": 100.0 * saturated / count,
    }


def detect_stars_from_pixels(
    pixels: list[int],
    width: int,
    height: int,
    threshold: int,
    min_area: int,
    max_area: int,
) -> list[dict[str, Any]]:
    visited = bytearray(width * height)
    stars: list[dict[str, Any]] = []

    def pixel_index(x: int, y: int) -> int:
        return y * width + x

    for y in range(height):
        for x in range(width):
            start_idx = pixel_index(x, y)
            if visited[start_idx] or pixels[start_idx] < threshold:
                continue

            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited[start_idx] = 1

            area = 0
            sum_i = 0
            sum_xi = 0
            sum_yi = 0
            max_y_value = 0
            min_x = x
            max_x = x
            min_y = y
            max_y = y

            while queue:
                cx, cy = queue.popleft()
                idx = pixel_index(cx, cy)
                intensity = pixels[idx]

                area += 1
                sum_i += intensity
                sum_xi += cx * intensity
                sum_yi += cy * intensity
                max_y_value = max(max_y_value, intensity)
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                for ny in range(cy - 1, cy + 2):
                    if ny < 0 or ny >= height:
                        continue
                    for nx in range(cx - 1, cx + 2):
                        if nx < 0 or nx >= width:
                            continue
                        nidx = pixel_index(nx, ny)
                        if visited[nidx] or pixels[nidx] < threshold:
                            continue
                        visited[nidx] = 1
                        queue.append((nx, ny))

            if area < min_area or area > max_area or sum_i <= 0:
                continue

            stars.append(
                {
                    "id": len(stars),
                    "x": sum_xi / sum_i,
                    "y": sum_yi / sum_i,
                    "area": area,
                    "max_y": max_y_value,
                    "bbox": [min_x, min_y, max_x, max_y],
                    "sum_y": sum_i,
                }
            )

    stars.sort(key=lambda item: item["sum_y"], reverse=True)
    for index, star in enumerate(stars):
        star["id"] = index
    return stars


def draw_detections(
    image: Image.Image,
    stars: list[dict[str, Any]],
    output_path: str | Path,
    color: tuple[int, int, int] = (255, 0, 0),
) -> Path:
    output = image.convert("RGB")
    draw = ImageDraw.Draw(output)

    for star in stars:
        x = float(star["x"])
        y = float(star["y"])
        radius = max(3.0, math.sqrt(float(star.get("area", 9))))
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=color, width=1)
        draw.line((x - radius, y, x + radius, y), fill=color, width=1)
        draw.line((x, y - radius, x, y + radius), fill=color, width=1)

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(output_path)
    return output_path


def load_json(path: str | Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def save_json(data: dict[str, Any], path: str | Path) -> Path:
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return output_path


def scale_expected_stars(
    expected: dict[str, Any],
    capture_width: int,
    capture_height: int,
) -> list[dict[str, Any]]:
    src_width = float(expected["width"])
    src_height = float(expected["height"])
    scale_x = capture_width / src_width
    scale_y = capture_height / src_height

    scaled: list[dict[str, Any]] = []
    for star in expected["stars"]:
        scaled.append(
            {
                "id": star["id"],
                "x": float(star["x"]) * scale_x,
                "y": float(star["y"]) * scale_y,
                "source_x": float(star["x"]),
                "source_y": float(star["y"]),
            }
        )
    return scaled


def match_centroids(
    expected_stars: list[dict[str, Any]],
    detected_stars: list[dict[str, Any]],
    max_match_error: float,
) -> dict[str, Any]:
    remaining = set(range(len(detected_stars)))
    matches: list[dict[str, Any]] = []
    missed: list[dict[str, Any]] = []

    for expected in expected_stars:
        best_index: int | None = None
        best_error = max_match_error

        for det_index in remaining:
            detected = detected_stars[det_index]
            dx = float(detected["x"]) - float(expected["x"])
            dy = float(detected["y"]) - float(expected["y"])
            error = math.sqrt(dx * dx + dy * dy)
            if error <= best_error:
                best_error = error
                best_index = det_index

        if best_index is None:
            missed.append(expected)
            continue

        remaining.remove(best_index)
        detected = detected_stars[best_index]
        matches.append(
            {
                "expected_id": expected["id"],
                "detected_id": detected["id"],
                "expected_x": expected["x"],
                "expected_y": expected["y"],
                "detected_x": detected["x"],
                "detected_y": detected["y"],
                "error_px": best_error,
            }
        )

    false_detections = [detected_stars[index] for index in sorted(remaining)]
    errors = [match["error_px"] for match in matches]

    return {
        "matches": matches,
        "missed": missed,
        "false_detections": false_detections,
        "matched_count": len(matches),
        "missed_count": len(missed),
        "false_count": len(false_detections),
        "mean_error_px": sum(errors) / len(errors) if errors else None,
        "max_error_px": max(errors) if errors else None,
    }


def recommendation(stats: dict[str, float], comparison: dict[str, Any]) -> str:
    max_y = stats["max_y"]
    mean_y = stats["mean_y"]
    std_y = stats["std_y"]
    saturated_pct = stats["saturated_pct"]
    missed_count = int(comparison.get("missed_count", 0))
    false_count = int(comparison.get("false_count", 0))

    if max_y < 50:
        return "Imagen muy oscura: subir exposicion o ganancia antes que brillo."
    if saturated_pct > 2.0:
        return "Hay saturacion: bajar exposicion, ganancia o contraste."
    if missed_count > 0 and false_count == 0:
        return "Faltan estrellas sin ruido excesivo: subir exposicion o ganancia ligeramente."
    if false_count > 0 and std_y > 25:
        return "Hay detecciones falsas y ruido: bajar ganancia o subir umbral."
    if mean_y > 70:
        return "Fondo alto: bajar brillo/ganancia o reducir luz ambiente."
    return "Captura util: ajustar buscando menor error promedio de centroides."
