from __future__ import annotations

import sys

from serial.tools import list_ports


def main() -> int:
    ports = sorted(list_ports.comports(), key=lambda item: item.device)

    if not ports:
        print("No se detectaron puertos serie.")
        return 1

    print("Puertos serie detectados:")
    for port in ports:
        desc = port.description or "Sin descripcion"
        hwid = port.hwid or "Sin HWID"
        print(f"- {port.device}: {desc} [{hwid}]")

    return 0


if __name__ == "__main__":
    sys.exit(main())
