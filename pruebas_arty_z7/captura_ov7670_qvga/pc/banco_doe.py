"""Local optical bench, D1-D3 only. Run --preflight before connecting the camera.
No measurements are fabricated: --self-test uses a distinct synthetic directory.
"""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import html
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import math
from pathlib import Path
import secrets
import sys
import threading
import time
from urllib.parse import urlsplit
import uuid

import numpy as np
from PIL import Image, ImageDraw
from doe_analysis import components, stats, fit_geometry, project, associations, response_curve
from doe_device import Camera, decode_profile, ROOT
from medir_estrella import measure

PPT = Path('C:/Users/alexa/OneDrive/Documentos/ChatGPT/Tesis/entrega_doe/Star_Tracker_DoE_FAT_Actualizado.pptx')
SCREEN = (2560,1440)
CENTER = (1279.5,719.5)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(value,indent=2,ensure_ascii=False,allow_nan=False),encoding='utf-8')
    temporary.replace(path)


def pattern(points=(), diameter=8, level=255, noise=0, seed=0, flat=None):
    rng=np.random.default_rng(seed)
    # With RGB background 0, symmetric Gaussian noise clips at zero. Record the
    # achieved statistics as well as sigma before clipping. This is scene noise.
    a=np.clip(np.rint(rng.normal(0,noise,(SCREEN[1],SCREEN[0]))),0,255).astype(np.uint8)
    if flat is not None:
        a.fill(flat)
    image=Image.fromarray(a)
    # Draw a coverage-antialiased disk in a small patch. Coordinates use pixel
    # centers (0,0) through (2559,1439), not CSS pixels or nominal camera pixels.
    for x,y in points:
        r=diameter/2
        x0,y0=int(math.floor(x-r-1)),int(math.floor(y-r-1))
        size=int(math.ceil(diameter+4))
        yy,xx=np.mgrid[:size*4,:size*4]
        coverage=(((x0+(xx+.5)/4-.5-x)**2+(y0+(yy+.5)/4-.5-y)**2)<=r*r)
        alpha=coverage.reshape(size,4,size,4).mean(axis=(1,3))
        patch=np.array(image.crop((x0,y0,x0+size,y0+size)))
        patch=np.rint(patch*(1-alpha)+level*alpha).astype(np.uint8)
        image.paste(Image.fromarray(patch),(x0,y0))
    return image, dict(width=SCREEN[0],height=SCREEN[1],points=list(points),diameter_monitor_px=diameter,
                       level_rgb=level,noise_sigma_before_clipping=noise,seed=seed,flat=flat,
                       achieved_background_mean=float(a.mean()),achieved_background_std=float(a.std()),
                       overlap_requested=any(math.dist(p,q)<diameter for i,p in enumerate(points) for q in points[i+1:]))


def display_ok(data):
    return (data.get('fullscreen') is True and data.get('visible') is True and
            abs(data.get('width',0)*data.get('dpr',0)-SCREEN[0])<1 and
            abs(data.get('height',0)*data.get('dpr',0)-SCREEN[1])<1)


class Bench:
    def __init__(self, output, port, physical=True):
        self.output=output; output.mkdir(parents=True,exist_ok=False)
        self.port=port; self.token=secrets.token_urlsafe(24)
        self.lock=threading.RLock(); self.stop=threading.Event(); self.visual=threading.Event()
        self.preview=threading.Event(); self.display_faults=0
        self.camera=None; self.png=b''; self.ack={}; self.ack_time=0; self.rows=[]; self.d1=[]
        self.state=dict(phase='ESPERANDO_MONTAJE',message='Montar y enfocar. Abrir /patron en el G5 y activar pantalla completa.',
                        scene=None,rows=0,visual_images=[],token=self.token)
        self.meta=dict(created_utc=datetime.now(timezone.utc).isoformat(),physical=physical,
                       centroid_source='PC_OFFLINE_Y8',fpga_centroids_measured=False,
                       scope='D1-D3 capture, size, centroid PC and separation; no identification/attitude',
                       protocol_ppt_sha256=hashlib.sha256(PPT.read_bytes()).hexdigest() if PPT.is_file() else None,
                       sources_sha256=self.hashes(),port=port,baud=115200)
        write_json(output/'manifest.json',self.meta)

    def hashes(self):
        paths=list((ROOT/'rtl').glob('*.vhd'))+list((ROOT/'arm/src').glob('*.c'))+list(Path(__file__).parent.glob('doe*.py'))+[Path(__file__)]
        paths+=list((ROOT/'build/diagnostico/resultados').glob('*.bit'))+list((ROOT/'build/diagnostico/resultados').glob('*.elf'))
        return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

    def update(self, phase, message):
        with self.lock:
            self.state.update(phase=phase,message=message,rows=len(self.rows))
            write_json(self.output/'state.json',{k:v for k,v in self.state.items() if k!='token'})
        print(phase,message,flush=True)

    def check(self):
        if self.stop.is_set():
            raise RuntimeError('Ensayo detenido por el operador')

    def wait(self, seconds):
        if self.stop.wait(seconds):
            self.check()

    def scene(self, name, **kwargs):
        self.check()
        image,meta=pattern(**kwargs); identity=uuid.uuid4().hex
        scene=dict(id=identity,name=name,**meta)
        directory=self.output/'patterns'; directory.mkdir(exist_ok=True)
        image.save(directory/f'{identity}.png')
        write_json(directory/f'{identity}.json',scene)
        stream=io.BytesIO(); image.save(stream,format='PNG')
        with self.lock:
            self.png=stream.getvalue(); self.state['scene']=scene
        deadline=time.monotonic()+60
        while time.monotonic()<deadline:
            self.check()
            with self.lock:
                ready=self.ack.get('id')==identity and display_ok(self.ack) and time.monotonic()-self.ack_time<2
            if ready:
                self.wait(1.0)  # presentation settling, not a measured camera exposure
                return scene
            self.wait(.1)
        raise TimeoutError('El G5 no confirmo patron completo a resolucion nativa en 60 s')

    def require_display(self, scene):
        with self.lock:
            if self.ack.get('id')!=scene['id'] or not display_ok(self.ack) or time.monotonic()-self.ack_time>2:
                raise RuntimeError('Patron sin confirmacion reciente: se descarta la captura')
            return self.display_faults

    def capture(self, condition, scene, registers, stage, repeat):
        self.check(); display_epoch=self.require_display(scene)
        started=time.monotonic()
        payload,messages=self.camera.capture()
        if self.require_display(scene)!=display_epoch:
            raise RuntimeError('La pantalla cambio durante la captura: no usar este cuadro')
        identity=f'{stage}_{condition}_{repeat:02d}_{uuid.uuid4().hex[:8]}'
        directory=self.output/'images'; directory.mkdir(exist_ok=True)
        image=Image.frombytes('L',(320,240),payload)
        image.save(directory/f'{identity}.png'); (directory/f'{identity}.raw').write_bytes(payload)
        row=dict(id=identity,stage=stage,condition=condition,repeat=repeat,scene=scene,
                 registers=registers,**decode_profile(registers),statistics=stats(image),messages=messages,
                 raw_sha256=hashlib.sha256(payload).hexdigest(),
                 elapsed_capture_transfer_seconds=time.monotonic()-started,
                 latency_interpretation='includes UART/ARM/PC; not FPGA processing latency',
                 image=f'images/{identity}.png',centroid_source='PC_OFFLINE_Y8')
        self.rows.append(row)
        write_json(self.output/'measurements.json',self.rows)
        with self.lock:
            self.state['rows']=len(self.rows)
        self.wait(.15)  # release of debounced software trigger
        return row,image

    def series(self, condition, scene, registers, stage, n=5):
        result=[]
        for i in range(n):
            self.update(stage,f'{condition}: captura {i+1}/{n}')
            result.append(self.capture(condition,scene,registers,stage,i+1))
        if self.camera.snapshot()!=registers:
            raise RuntimeError('Los registros cambiaron durante la serie: resultados invalidados')
        return result

    def radiometry(self, registers, stage):
        rows=[]; black=[]
        for level in (0,16,32,64,96,128,160,192,224,240,255):
            scene=self.scene(f'{stage}_RGB_{level}',flat=level)
            for row,image in self.series(str(level),scene,registers,stage,n=3):
                patch=np.asarray(image)[105:135,145:175]
                rows.append(dict(level=level,patch_mean=float(patch.mean()),patch_max=int(patch.max()),id=row['id']))
                if level==0: black.append(np.asarray(image))
        curve=response_curve(rows)
        noise=float(np.std(np.stack(black).astype(float),axis=0).mean())
        threshold=int(math.ceil(max(stats(x)['p999'] for x in black)+max(5,5*noise)))
        if curve['span_y']<10 or not curve['monotonic_with_2dn_tolerance'] or threshold>=245:
            raise RuntimeError('Respuesta RGB->Y insuficiente/no monotona: revisar montaje, ajustes o byte Y')
        curve.update(rows=rows,temporal_black_noise_std=noise,threshold_y=threshold,
                     threshold_rule='ceil(max black p99.9 + max(5, 5*mean temporal sigma))',
                     auto_controls_frozen=True,full_frame_black=[stats(x) for x in black])
        write_json(self.output/f'{stage}.json',curve)
        return curve

    def run(self):
        try:
            self.camera=Camera(self.port,self.output); self.camera.handshake()
            scene=self.scene('comprobacion_inicial',points=[CENTER],diameter=8)
            # The first capture initializes the original 21-register camera ROM.
            payload,messages=self.camera.capture()
            initial=Image.frombytes('L',(320,240),payload)
            initial.save(self.output/'initial_auto.png'); (self.output/'initial_auto.raw').write_bytes(payload)
            self.meta['initial_messages']=messages
            self.visual.clear()
            self.update('ENFOQUE_VISUAL','Revisa initial_auto.png. Ajusta foco fisicamente si hace falta y pulsa Confirmar enfoque. Despues no mover el montaje.')
            while not self.visual.wait(.2):
                self.check()
                if self.preview.is_set():
                    self.preview.clear(); self.require_display(scene)
                    payload,messages=self.camera.capture()
                    Image.frombytes('L',(320,240),payload).save(self.output/'initial_auto.png')
                    (self.output/'initial_auto.raw').write_bytes(payload)
                    self.meta.setdefault('focus_previews',[]).append(dict(time=time.time(),messages=messages,
                        sha256=hashlib.sha256(payload).hexdigest()))
            self.wait(3)
            auto=self.camera.snapshot(); frozen=self.camera.freeze()
            self.meta.update(auto_registers=auto,frozen_registers=frozen)
            write_json(self.output/'manifest.json',self.meta)
            initial_curve=self.radiometry(frozen,'CAL_INICIAL')
            threshold=initial_curve['threshold_y']
            base=min(510,max(1,decode_profile(frozen)['exposure_code']))
            candidates=sorted({max(1,min(510,int(round(base*f)))) for f in (.25,.5,1,2)})
            pilots=[]
            for e in candidates:
                regs=self.camera.profile(e,0); self.wait(.5)
                scene=self.scene(f'piloto_AEC_{e}',points=[CENTER],diameter=8)
                row,image=self.capture(f'E{e}',scene,regs,'PILOTO',1)
                blobs,_=components(image,threshold)
                good=[b for b in blobs if b['accepted'] and not b['touches_edge']]
                pilots.append(dict(e=e,peak=row['statistics']['max'],valid=len(good)==1 and row['statistics']['max']<250))
            useful=[p for p in pilots if p['valid']]
            if not useful: raise RuntimeError('Piloto sin punto aislado util. Revisar foco/luz; no generar D1 con una escena invalida.')
            chosen=max(useful,key=lambda p:p['peak'])['e']
            exposures=sorted({max(1,min(510,round(chosen*f))) for f in (.7,1,1.3)})
            for e in range(1,511):
                if len(exposures)==3: break
                if e not in exposures: exposures.append(e)
            exposures.sort()
            self.meta['d1_levels']=dict(exposure_codes=exposures,gain_codes=[0,16],pilot=pilots,rule='three codes around highest nonsaturated isolated pilot; AGC codes 0/16')
            conditions=[(e,g) for e in exposures for g in (0,16)]
            rng=np.random.default_rng(20261110); order=rng.permutation(6).tolist()
            self.meta['d1_order']=order; write_json(self.output/'manifest.json',self.meta)
            for index in order:
                e,g=conditions[index]; name=f'C{index+1:02d}'
                regs=self.camera.profile(e,g); self.wait(.5)
                scene=self.scene(name,points=[CENTER],diameter=8)
                for row,image in self.series(name,scene,regs,'D1'):
                    row['point']=measure(image,radius=15,threshold=threshold)
                    self.d1.append(row)
            with self.lock:
                self.state['visual_images']=[dict(id=r['id'],condition=r['condition'],image=r['image'],exposure=r['exposure_code'],gain=r['gain_code']) for r in self.d1]
            self.visual.clear()
            self.update('CRITERIO_VISUAL_D1','Completa las 30 fichas y elige C01..C06. Se conserva la misma ampliacion. Se espera tu criterio antes de D2.')
            while not self.visual.wait(.2): self.check()
            selected=self.selection
            profile=next(r for r in self.d1 if r['condition']==selected)
            regs=self.camera.profile(profile['exposure_code'],profile['gain_code']); self.wait(.5)
            self.meta['selected_D1']=selected
            curve=self.radiometry(regs,'CAL_PERFIL_FINAL'); threshold=curve['threshold_y']
            self.meta['analysis_threshold_y']=threshold
            geometry=self.geometry(regs,threshold)
            self.meta['geometry']=geometry
            # D2 uses only the selected fixed D1 profile and monitor diameter.
            d2=[]
            for index,(diameter,dx) in enumerate(( (d,x) for d in (4,8,12) for x in (0,50) )):
                name=f'P{index+1:02d}'; points=[(CENTER[0]+dx,CENTER[1])]
                scene=self.scene(name,points=points,diameter=diameter)
                expected=project(points,geometry)[0]
                for row,image in self.series(name,scene,regs,'D2'):
                    blobs,labels=components(image,threshold)
                    gate=max(2,min(5,diameter*.7))
                    row['association']=associations(blobs,labels,[expected],gate)
                    row['expected_camera_px']=[expected]; row['blobs_pc']=blobs
                    row['point']=measure(image,center=tuple(round(x) for x in expected),radius=15,threshold=threshold)
                    row['diameter_monitor_px']=diameter
                    d2.append(row)
            scores=[]
            for diameter in (4,8,12):
                rows=[r for r in d2 if r['diameter_monitor_px']==diameter]
                eligible=all(r['association']['correct']==1 and r['association']['false_components']==0 and
                             r['statistics']['max']<250 and not r['point']['flags'] for r in rows)
                variances=[]
                for dx in (0,50):
                    subset=[r for r in rows if r['scene']['points'][0][0]==CENTER[0]+dx]
                    values=[[r['point']['centroid_x'],r['point']['centroid_y']] for r in subset]
                    if any(None in v for v in values): variances.append(None)
                    else:
                        sd=np.std(np.array(values,float),axis=0); variances.append(float(sd.dot(sd)))
                scores.append(dict(diameter=diameter,eligible=eligible,
                                   jitter_radial_px=math.sqrt(np.mean(variances)) if None not in variances else None))
            eligible=[s for s in scores if s['eligible']]
            if not eligible: raise RuntimeError('D2 no encontro tamano sin banderas en las 10 capturas; revisar antes de D3')
            diameter=min(eligible,key=lambda s:s['jitter_radial_px'])['diameter']
            self.meta['D2_selection']=dict(scores=scores,selected_diameter_monitor_px=diameter,rule='minimum PC temporal radial jitter among sizes with 10/10 valid single detections; no FPGA accuracy claim')
            # Freeze association gate before seeing the D3 measurements.
            scale=float(np.linalg.norm(np.array(geometry['matrix'])[0]))
            gate=max(1.0,min(2.0,8*scale*.4))
            self.meta['D3_gate_camera_px']=gate
            for index,(sep,noise) in enumerate(( (s,n) for s in (8,16,24) for n in (0,8) )):
                name=f'R{index+1:02d}'; points=[(CENTER[0]+k*sep,CENTER[1]) for k in (-2,-1,0,1,2)]
                scene=self.scene(name,points=points,diameter=diameter,noise=noise,seed=20261110+index)
                expected=project(points,geometry)
                for row,image in self.series(name,scene,regs,'D3'):
                    blobs,labels=components(image,threshold)
                    row['blobs_pc']=blobs; row['expected_camera_px']=expected
                    row['association']=associations(blobs,labels,expected,gate)
            write_json(self.output/'manifest.json',self.meta)
            write_json(self.output/'measurements.json',self.rows)
            self.report()
            self.update('COMPLETO_D1_D3','Terminado hasta separacion. Informe y evidencias guardados. PPT original conservado.')
        except Exception as exc:
            self.meta['failure']=repr(exc); write_json(self.output/'manifest.json',self.meta)
            write_json(self.output/'measurements.json',self.rows)
            self.report()
            self.update('DETENIDO',str(exc))
        finally:
            if self.camera: self.camera.close()

    def geometry(self,regs,threshold):
        screen=[]; camera=[]
        positions=[(dx,dy) for dy in (-60,0,60) for dx in (-60,0,60)]
        for index,(dx,dy) in enumerate(positions):
            point=(CENTER[0]+dx,CENTER[1]+dy)
            scene=self.scene(f'geometria_{index}',points=[point],diameter=8)
            centers=[]
            for row,image in self.series(f'G{index}',scene,regs,'GEOMETRIA',n=3):
                blobs,_=components(image,threshold)
                valid=[b for b in blobs if b['accepted'] and not b['touches_edge']]
                if len(valid)!=1: raise RuntimeError('Geometria requiere una sola fuente aislada en cada toma')
                centers.append([valid[0]['x'],valid[0]['y']])
            screen.append(point); camera.append(np.mean(centers,axis=0).tolist())
        geometry=fit_geometry(screen,camera,[0,1,2,3,6,8])
        geometry.update(screen_points=screen,camera_centers=camera)
        write_json(self.output/'geometry.json',geometry)
        if geometry['heldout_max_px']>1.0:
            raise RuntimeError('Geometria local con error de comprobacion >1 px: realinear o reducir region')
        return geometry

    def accept_visual(self,data):
        if self.state['phase']=='ENFOQUE_VISUAL':
            if data.get('focus_confirmed') is not True: raise ValueError('Falta confirmar el enfoque')
            self.visual.set(); return
        if self.state['phase']!='CRITERIO_VISUAL_D1': raise ValueError('No se espera evaluacion D1')
        records=data.get('records',[])
        if len(records)!=30 or {r['id'] for r in records}!={r['id'] for r in self.d1}:
            raise ValueError('Se requieren las 30 fichas D1 sin duplicados')
        for r in records:
            if any(type(r.get(key)) is not bool for key in ('complete','distinct','contour')):
                raise ValueError('Cada criterio debe registrar si/no')
        selected=data.get('selected')
        rows=[r for r in self.d1 if r['condition']==selected]
        if len(rows)!=5 or not data.get('reason','').strip(): raise ValueError('Elegir condicion y justificar')
        if any(r['statistics']['max']>=250 for r in rows): raise ValueError('La condicion seleccionada alcanza el margen de saturacion; repetir piloto')
        self.selection=selected
        write_json(self.output/'visual_D1.json',data)
        self.visual.set()

    def report(self):
        flat=[]
        for row in self.rows:
            point=row.get('point',{}); assoc=row.get('association',{})
            flat.append(dict(id=row['id'],stage=row['stage'],condition=row['condition'],repeat=row['repeat'],
                             exposure_code=row['exposure_code'],gain_code=row['gain_code'],
                             peak_y=row['statistics']['max'],centroid_x_pc=point.get('centroid_x'),centroid_y_pc=point.get('centroid_y'),
                             fwhm_x=point.get('fwhm_x'),fwhm_y=point.get('fwhm_y'),flags=point.get('flags'),
                             correct=assoc.get('correct'),expected=assoc.get('expected'),fused_sources=assoc.get('fused_sources'),
                             omissions=assoc.get('omissions'),false_components=assoc.get('false_components')))
        if flat:
            with (self.output/'measurements.csv').open('w',newline='',encoding='utf-8-sig') as f:
                writer=csv.DictWriter(f,fieldnames=flat[0]); writer.writeheader(); writer.writerows(flat)
        summaries=[]
        for condition in sorted({r['condition'] for r in self.rows if r['stage'] in ('D2','D3')}):
            rows=[r for r in self.rows if r['condition']==condition and 'association' in r]
            errors=[m['error_pc_px'] for r in rows for m in r['association']['matches']]
            valid=[r['point'] for r in rows if r.get('point',{}).get('centroid_x') is not None]
            summary=dict(condition=condition,n_frames=len(rows),source='PC_OFFLINE_Y8',
                         **{k:sum(r['association'][k] for r in rows) for k in ('correct','expected','fused_sources','fusion_components','omissions','false_components')},
                         empirical_reference_radial_rms_px=math.sqrt(np.mean(np.square(errors))) if errors else None)
            if valid:
                summary.update(centroid_std_x_pc_px=float(np.std([p['centroid_x'] for p in valid])),
                               centroid_std_y_pc_px=float(np.std([p['centroid_y'] for p in valid])),
                               fwhm_x_mean_px=float(np.mean([p['fwhm_x'] for p in valid if p['fwhm_x'] is not None])) if any(p['fwhm_x'] is not None for p in valid) else None,
                               fwhm_y_mean_px=float(np.mean([p['fwhm_y'] for p in valid if p['fwhm_y'] is not None])) if any(p['fwhm_y'] is not None for p in valid) else None)
            summaries.append(summary)
        write_json(self.output/'summaries.json',summaries)
        parts=['<!doctype html><meta charset="utf-8"><title>Ensayo Arty D1-D3</title>',
               '<style>body{font:16px system-ui;max-width:1200px;margin:40px auto}td,th{padding:8px;border-bottom:1px solid #ddd}img{width:320px;image-rendering:pixelated}</style>',
               '<h1>Captura QVGA y separacion de fuentes</h1>',
               '<p>Centroides calculados en PC sobre Y8. Salida de centroide FPGA y FAT F02 sin evaluar. No se realizaron identificacion ni actitud.</p>']
        if not self.meta['physical']:
            parts.insert(2,'<h1>PRUEBA SINTETICA DE SOFTWARE. SIN MEDICIONES FISICAS.</h1>')
        if 'failure' in self.meta: parts.append('<p>Ensayo detenido: '+html.escape(self.meta['failure'])+'</p>')
        parts.append('<table><tr><th>Condicion</th><th>N</th><th>Asociadas/esperadas</th><th>Fuentes fusionadas</th><th>Omisiones</th><th>Falsas</th></tr>')
        for condition in sorted({r['condition'] for r in self.rows if r['stage'] in ('D2','D3')}):
            rows=[r for r in self.rows if r['condition']==condition and 'association' in r]
            totals={k:sum(r['association'][k] for r in rows) for k in ('correct','expected','fused_sources','omissions','false_components')}
            parts.append(f'<tr><td>{condition}</td><td>{len(rows)}</td><td>{totals["correct"]}/{totals["expected"]}</td><td>{totals["fused_sources"]}</td><td>{totals["omissions"]}</td><td>{totals["false_components"]}</td></tr>')
        parts.append('</table><p>La dispersion temporal y el error contra un mapa empirico local se registran aparte. No demuestran RMS FPGA &le;0,2 px. Cinco tomas por condicion son caracterizacion inicial.</p>')
        parts.append('<p>Superposiciones: verde = referencia empirica de pantalla; magenta = centroide calculado en PC. Los originales PNG/RAW se conservan completos.</p>')
        for row in self.rows:
            if row['stage'] in ('D1','D2','D3') and row['repeat']==1:
                if row.get('expected_camera_px'):
                    drawing=[f'<svg width="640" height="480" viewBox="0 0 320 240"><image href="{row["image"]}" width="320" height="240" style="image-rendering:pixelated"/>']
                    for color,points in [('lime',row['expected_camera_px']),('magenta',[[b['x'],b['y']] for b in row.get('blobs_pc',[]) if b['accepted']])]:
                        for x,y in points:
                            drawing.append(f'<path d="M {x-3} {y} h 6 M {x} {y-3} v 6" fill="none" stroke="{color}" stroke-width="0.5"/>')
                    drawing.append('</svg>'); picture=''.join(drawing)
                else: picture=f'<img src="{row["image"]}">'
                parts.append(f'<figure>{picture}<figcaption>{row["stage"]} {row["condition"]}</figcaption></figure>')
        (self.output/'report.html').write_text('\n'.join(parts),encoding='utf-8')


def make_handler(bench):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def send(self,body,kind='application/json',status=200):
            if isinstance(body,(dict,list)): body=json.dumps(body).encode()
            if isinstance(body,str): body=body.encode('utf-8')
            self.send_response(status); self.send_header('Content-Type',kind+'; charset=utf-8')
            self.send_header('Cache-Control','no-store'); self.send_header('Content-Length',str(len(body)))
            self.end_headers(); self.wfile.write(body)
        def do_GET(self):
            path=urlsplit(self.path).path
            if path=='/api/state':
                with bench.lock: self.send(dict(bench.state))
            elif path=='/scene.png':
                with bench.lock: self.send(bench.png,'image/png')
            elif path in ('/','/patron'):
                self.send((Path(__file__).parent/'doe_web'/('patron.html' if path=='/patron' else 'operator.html')).read_text(encoding='utf-8'),'text/html')
            elif path.startswith('/images/') or path=='/initial_auto.png':
                target=(bench.output/path.lstrip('/')).resolve()
                if target.is_relative_to(bench.output.resolve()) and target.is_file(): self.send(target.read_bytes(),'image/png')
                else: self.send({'error':'No encontrado'},status=404)
            else: self.send({'error':'No encontrado'},status=404)
        def do_POST(self):
            # Loopback-only server. Reject cross-origin mutations and require a
            # per-run token except for the display heartbeat (read-only evidence).
            try:
                if self.headers.get('Origin') not in (None,f'http://{self.headers.get("Host")}'):
                    raise ValueError('Origen no permitido')
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<100000: raise ValueError('Tamano no permitido')
                data=json.loads(self.rfile.read(length))
                if self.path=='/api/display':
                    with bench.lock:
                        if not display_ok(data) or (bench.state['scene'] and data.get('id')!=bench.state['scene']['id']):
                            bench.display_faults+=1
                        bench.ack=data; bench.ack_time=time.monotonic()
                elif self.headers.get('X-Bench-Token')!=bench.token:
                    raise ValueError('Token invalido')
                elif self.path=='/api/start':
                    if bench.state['phase']!='ESPERANDO_MONTAJE': raise ValueError('Ya iniciado')
                    required=('fixed_mount','focus_ready','hdr_off','native_resolution','monitor_brightness_zero','monitor_confirmed')
                    if any(data.get(k) is not True for k in required) or not data.get('refresh_hz') or not data.get('distance_mm'):
                        raise ValueError('Completar las condiciones del banco')
                    if not display_ok(bench.ack) or time.monotonic()-bench.ack_time>2: raise ValueError('Abrir /patron en el G5 y activar pantalla completa')
                    bench.meta['setup']=data; write_json(bench.output/'manifest.json',bench.meta)
                    bench.update('INICIANDO','Abriendo Arty y comprobando firmware DOE1')
                    threading.Thread(target=bench.run,daemon=True).start()
                elif self.path=='/api/visual': bench.accept_visual(data)
                elif self.path=='/api/preview':
                    if bench.state['phase']!='ENFOQUE_VISUAL': raise ValueError('Solo durante el enfoque')
                    bench.preview.set()
                elif self.path=='/api/stop': bench.stop.set()
                else: raise ValueError('Ruta no permitida')
                self.send({'ok':True})
            except Exception as exc: self.send({'error':str(exc)},status=400)
    return Handler


def preflight():
    sys.path.insert(0,str(ROOT/'build/python_deps'))
    import serial
    from serial.tools.list_ports import comports
    files=['sistema_captura_arm_wrapper.bit','sistema_captura_arm_wrapper.xsa','receptor_ov7670_test.elf','ps7_init.tcl']
    artifacts={name:(ROOT/'build/diagnostico/resultados'/name).is_file() for name in files}
    seal=ROOT/'build/diagnostico/resultados/doe_release.json'
    verified=False
    if seal.is_file():
        release=json.loads(seal.read_text(encoding='utf-8'))
        verified=all((ROOT/name).is_file() and hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest
                     for name,digest in release['sha256'].items())
    report=dict(python=sys.executable,pillow=Image.__version__,numpy=np.__version__,pyserial=serial.__version__,
                ports=[dict(device=p.device,description=p.description,hwid=p.hwid) for p in comports()],
                artifacts=artifacts,release_hashes_match=verified,physical_test_performed=False,
                next='load_capture.tcl then banco_doe.py; inspect runtime firmware and sensor on first capture')
    print(json.dumps(report,indent=2,ensure_ascii=False))
    return 0 if all(artifacts.values()) and verified else 1


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preflight',action='store_true')
    parser.add_argument('--port',default='COM3')
    parser.add_argument('--http-port',type=int,default=8765)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.preflight: return preflight()
    if preflight(): return 1
    output=args.output or ROOT/'build/ensayos_doe'/datetime.now().strftime('%Y%m%d_%H%M%S')
    bench=Bench(output,args.port)
    server=ThreadingHTTPServer(('127.0.0.1',args.http_port),make_handler(bench))
    print(f'Operador: http://127.0.0.1:{args.http_port}/\nG5: http://127.0.0.1:{args.http_port}/patron\nEvidencias: {output}',flush=True)
    try: server.serve_forever(poll_interval=.2)
    except KeyboardInterrupt: bench.stop.set()
    finally: server.server_close()
    return 0


if __name__=='__main__': raise SystemExit(main())
