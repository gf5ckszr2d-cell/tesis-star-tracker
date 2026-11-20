"""Geometria nominal del patron fijo. No lee ni modifica RTL ni calibra la camara."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / 'Generador_G5/patrones/sintetico48_s20261119/referencia.json'
if not REFERENCE.exists():
    REFERENCE = ROOT / 'Star_Tracker_FPGA/Star_Tracker_Oficial/Generadores/Generador_cielo_G5/patrones/sintetico48_s20261119/referencia.json'
DEFAULTS = dict(screen_width_mm=596.736, screen_height_mm=335.664,
                screen_width_convention='arc', radius_mm=1000.0, distance_mm=250.0,
                screen_width_px=2560, screen_height_px=1440,
                image_width_px=320, image_height_px=240, horizontal_fov_deg=25.0,
                cx_px=159.5, cy_px=119.5,
                pose='centered_aligned', distortion='not_calibrated_assumed_zero',
                horizontal_fov_source='Existing project assumption; exact lens FOV not established',
                screen_width_source='Samsung nominal active width; interpretation as arc is a model assumption',
                status='NOMINAL_UNCALIBRATED')

def dimensions(p):
    width = p['screen_width_mm']
    r = p['radius_mm']
    arc = width if p['screen_width_convention'] == 'arc' else 2*r*math.asin(width/(2*r))
    return arc, 2*r*math.sin(arc/(2*r))

def camera(p):
    w, h = p['image_width_px'], p['image_height_px']
    th = math.tan(math.radians(p['horizontal_fov_deg']) / 2)
    fx = w/(2*th)
    return dict(fx=fx, fy=fx, cx=p['cx_px'], cy=p['cy_px'], tan_h=th,
                tan_v=th*h/w, vertical_fov_deg=math.degrees(2*math.atan(th*h/w)))

def point(u, v, p):
    arc, _ = dimensions(p)
    s = (u + .5 - p['screen_width_px']/2)*arc/p['screen_width_px']
    y_up = (p['screen_height_px']/2-v-.5)*p['screen_height_mm']/p['screen_height_px']
    a = s/p['radius_mm']
    x = p['radius_mm']*math.sin(a)
    delta = p['radius_mm']*(1-math.cos(a))
    return dict(s_mm=s, y_panel_up_mm=y_up, alpha_rad=a, sag_mm=delta,
                Xc_mm=x, Yc_mm=-y_up, Zc_mm=p['distance_mm']-delta,
                x_from_left_arc_mm=(u+.5)*arc/p['screen_width_px'],
                y_from_bottom_mm=(p['screen_height_px']-v-.5)*p['screen_height_mm']/p['screen_height_px'])

def project(star, p):
    q, k = point(star['x'], star['y'], p), camera(p)
    x, y, z = q['Xc_mm'], q['Yc_mm'], q['Zc_mm']
    if z <= 0:
        raise ValueError('La escena nominal exige todos los puntos delante de la camara')
    u, v = k['cx']+k['fx']*x/z, k['cy']+k['fy']*y/z
    norm = math.sqrt(x*x+y*y+z*z)
    # Pixel centers are integer indices; sensor edges are -0.5 and N-0.5.
    inside = -.5 <= u < p['image_width_px']-.5 and -.5 <= v < p['image_height_px']-.5
    return dict(id=star['id'], u_monitor=star['x'], v_monitor=star['y'], **q,
                range_mm=norm, rx=x/norm, ry=y/norm, rz=z/norm,
                u_expected=u, v_expected=v, inside_nominal_fov=inside,
                u_scaled_256=round(u*256) if inside else None,
                v_scaled_256=round(v*256) if inside else None)

def ray_to_screen(xn, yn, p):
    """Inverse ideal projection. x=X/Z, y=Y/Z in the camera frame."""
    r, d = p['radius_mm'], p['distance_mm']
    b = r-d
    z = (-b+math.sqrt(r*r*(1+xn*xn)-xn*xn*b*b))/(1+xn*xn)
    x, y = xn*z, yn*z
    a = math.atan2(x, z-d+r)
    arc, _ = dimensions(p)
    return dict(u_monitor=(a*r/arc+.5)*p['screen_width_px']-.5,
                v_monitor=(y/p['screen_height_mm']+.5)*p['screen_height_px']-.5,
                Xc_mm=x, Yc_mm=y, Zc_mm=z)

def threshold_scenarios(stars, p):
    k = camera(p)
    distances, fovs = [], []
    for s in stars:
        q = point(s['x'], s['y'], p)
        distances.append((q['sag_mm']+max(abs(q['Xc_mm'])/k['tan_h'],abs(q['Yc_mm'])/k['tan_v']), s['id']))
        fovs.append((math.degrees(2*math.atan(max(abs(q['Xc_mm'])/q['Zc_mm'],abs(q['Yc_mm'])/q['Zc_mm']*p['image_width_px']/p['image_height_px']))),s['id']))
    distances.sort(); fovs.sort()
    d8 = (distances[7][0]+distances[8][0])/2
    h8 = (fovs[7][0]+fovs[8][0])/2
    return dict(distance_interval_mm=[distances[7][0], distances[8][0]],
                distance_example_mm=d8,
                fov_interval_deg=[fovs[7][0],fovs[8][0]], fov_example_deg=h8,
                eight_at_alternative_distance=[project(s,{**p,'distance_mm':d8}) for s in stars
                                               if project(s,{**p,'distance_mm':d8})['inside_nominal_fov']])

def calculate(reference, p):
    rows = [project(s, p) for s in reference['stars']]
    arc, chord = dimensions(p); k = camera(p)
    # Independent algebraic invariants, inverse reprojection and bounds.
    for row in rows:
        x,y,z = (row[n] for n in ['Xc_mm','Yc_mm','Zc_mm'])
        assert math.isclose(x*x+(z-p['distance_mm']+p['radius_mm'])**2,p['radius_mm']**2,rel_tol=1e-12)
        assert math.isclose(row['rx']**2+row['ry']**2+row['rz']**2,1,abs_tol=1e-12)
        inv = ray_to_screen(x/z,y/z,p)
        assert math.isclose(inv['u_monitor'],row['u_monitor'],abs_tol=1e-8)
        assert math.isclose(inv['v_monitor'],row['v_monitor'],abs_tol=1e-8)
    boundary = [ray_to_screen(k['tan_h']*x,k['tan_v']*y,p)
                for x,y in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(1,1),(-1,1)]]
    scenarios = threshold_scenarios(reference['stars'],p)
    assert len(scenarios['eight_at_alternative_distance']) == 8
    return dict(parameters=p, camera=k, pattern_id=reference['patternId'],
                geometry=dict(arc_width_mm=arc,chord_width_mm=chord,
                    horizontal_pitch_mm=arc/p['screen_width_px'],vertical_pitch_mm=p['screen_height_mm']/p['screen_height_px'],
                    edge_sag_mm=p['radius_mm']*(1-math.cos(arc/(2*p['radius_mm']))),
                    central_flat_footprint_mm=[2*p['distance_mm']*k['tan_h'],2*p['distance_mm']*k['tan_v']],
                    curved_horizontal_footprint_mm=boundary[1]['Xc_mm']-boundary[0]['Xc_mm'],
                    arc_footprint_mm=(boundary[1]['u_monitor']-boundary[0]['u_monitor'])*arc/p['screen_width_px']),
                visible_ids=[s['id'] for s in rows if s['inside_nominal_fov']],
                stars=rows, boundary=boundary, scenarios=scenarios,
                checks='PASS cylinder equation, unit rays, inverse reprojection for 48 stars, alternative eight count')

def write_csv(path, rows, fieldnames=None):
    with path.open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fieldnames or list(rows[0])); writer.writeheader(); writer.writerows(rows)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--referencia',type=Path,default=REFERENCE)
    parser.add_argument('--parametros',type=Path)
    parser.add_argument('--out',type=Path,default=Path(__file__).parent/'resultados_nominales')
    args=parser.parse_args(); p=DEFAULTS.copy()
    if args.parametros: p.update(json.loads(args.parametros.read_text(encoding='utf-8')))
    assert p['screen_width_convention'] in ('arc','chord')
    assert 0 < p['horizontal_fov_deg'] < 120
    reference=json.loads(args.referencia.read_text(encoding='utf-8'))
    assert (reference['width'],reference['height']) == (p['screen_width_px'],p['screen_height_px'])
    result=calculate(reference,p)
    result['reference_sha256']=hashlib.sha256(args.referencia.read_bytes()).hexdigest()
    args.out.mkdir(parents=True,exist_ok=True)
    (args.out/'calculo.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    (args.out/'parametros.json').write_text(json.dumps(p,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    write_csv(args.out/'referencia_48.csv',result['stars'])
    write_csv(args.out/'referencia_visible_25cm_25grados.csv',[s for s in result['stars'] if s['inside_nominal_fov']],list(result['stars'][0]))
    box=reference['preview']
    write_csv(args.out/'ocho_del_recorte_digital.csv',[s for s in result['stars'] if
        box['x'] <= s['u_monitor'] < box['x']+box['width'] and box['y'] <= s['v_monitor'] < box['y']+box['height']])
    write_csv(args.out/'ocho_solo_distancia_alternativa.csv',result['scenarios']['eight_at_alternative_distance'])
    print(json.dumps(dict(visible=result['visible_ids'],geometry=result['geometry'],camera=result['camera'],
        distance_interval_mm=result['scenarios']['distance_interval_mm'],fov_interval_deg=result['scenarios']['fov_interval_deg'],
        checks=result['checks']),ensure_ascii=False,indent=2))

if __name__ == '__main__': main()
