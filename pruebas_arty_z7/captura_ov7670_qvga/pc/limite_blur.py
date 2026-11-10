"""Pinhole motion-smear budget near optical axis, not a measured slew limit."""
import argparse
import json
import math


def angular_limit(focal_px, exposure_ms, blur_px=.5):
    if min(focal_px,exposure_ms,blur_px)<=0:
        raise ValueError('Focal, exposure and blur must be positive')
    # Exact centre displacement for constant yaw/pitch from zero angle.
    return math.degrees(math.atan(blur_px/focal_px))/(exposure_ms/1000)


def main():
    p=argparse.ArgumentParser(description='Presupuesto de arrastre al centro para giro yaw/pitch')
    g=p.add_mutually_exclusive_group(required=True)
    g.add_argument('--focal-px',type=float,help='fx o fy calibrado en pixeles')
    g.add_argument('--fov-deg',type=float,help='FOV supuesto o medido; indicar su procedencia')
    p.add_argument('--width',type=int,default=320)
    p.add_argument('--exposure-ms',type=float,nargs='+',required=True)
    p.add_argument('--blur-px',type=float,default=.5)
    a=p.parse_args()
    if a.width<=0 or (a.fov_deg is not None and not 0<a.fov_deg<180):
        p.error('Ancho positivo y FOV entre 0 y 180 grados')
    focal=a.focal_px if a.focal_px is not None else a.width/(2*math.tan(math.radians(a.fov_deg)/2))
    try:
        rows=[dict(exposure_ms=t,omega_deg_s=angular_limit(focal,t,a.blur_px)) for t in a.exposure_ms]
    except ValueError as exc:
        p.error(str(exc))
    print(json.dumps(dict(model='Pinhole centre, constant yaw/pitch, exposure-smear budget only',
          focal_px=focal,blur_budget_px=a.blur_px,results=rows,
          warning='NOT measured. Requires calibrated focal/exposure. Edges, roll, distortion, rolling shutter and identification may impose lower limits.'),indent=2))


if __name__=='__main__': main()
