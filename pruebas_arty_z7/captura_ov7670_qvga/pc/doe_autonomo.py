"""Local adaptive D1-D3 execution. No RTL changes, upload or human-judgement claims."""
import argparse
from datetime import datetime, timezone, timedelta
import io
import json
import math
import subprocess
from pathlib import Path
import threading
import time
import uuid
from http.server import ThreadingHTTPServer
import numpy as np
from PIL import Image
from banco_doe import Bench, ROOT, CENTER, SCREEN, pattern, write_json, make_handler, display_ok
from doe_device import Camera, decode_profile
from doe_analysis import components, stats, associations, project, fit_geometry, response_curve
from medir_estrella import measure

FIELD = [(CENTER[0]+dx,CENTER[1]+dy) for dx,dy in [(0,0),(-70,-50),(70,-50),(-70,50),(70,50)]]
CRITICAL = [0x0A,0x0B,0x00,0x03,0x04,0x07,0x10,0x11,0x12,0x13,0x3A,0x3B,0x3D,0x3E,0x40]


class PacedCamera(Camera):
    """Physical trial showed paced accesses succeed; root cause is not established."""
    def __init__(self,port,output):
        super().__init__(port,output)
        if hasattr(self.port,'set_buffer_size'):
            self.port.set_buffer_size(rx_size=262144,tx_size=4096)

    def exchange(self,command,predicate,timeout=3):
        if command=='c':timeout=max(timeout,60)
        for attempt in range(3):
            last=getattr(self,'last_exchange',0)
            time.sleep(max(0,.25-(time.monotonic()-last)))
            try:
                return super().exchange(command,predicate,timeout)
            except RuntimeError as exc:
                # Only bounded register access retries. Profile writes are idempotent;
                # Camera.write still verifies the resulting register by readback.
                if command[:1] not in ('r','w') or str(exc) not in ('ERROR DOE SCCB 2','ERROR DOE SCCB 3') or attempt==2:
                    raise
                self.commands.write(json.dumps(dict(time=time.time(),event='SCCB_TRANSIENT_RETRY',
                    command=command,error=str(exc),retry=attempt+1))+'\n');self.commands.flush()
                time.sleep(1)
            finally: self.last_exchange=time.monotonic()
    def snapshot(self):
        r={f'{reg:02X}':self.read(reg) for reg in CRITICAL}
        if r['0A']!=0x76: raise RuntimeError('PID de camara inesperado')
        return r


def field_quality(image, expected=5):
    a=np.asarray(image,dtype=np.uint8); bg=float(np.median(a))
    sigma=max(1.,float(1.4826*np.median(abs(a.astype(float)-bg))))
    threshold=min(254,int(math.ceil(bg+max(5,6*sigma))))
    blobs,labels=components(a,threshold)
    good=[b for b in blobs if b['accepted']]
    reasons=[]
    if len(good)!=expected: reasons.append(f'SOURCES_{len(good)}_EXPECTED_{expected}')
    if any(b['peak']>=250 for b in good): reasons.append('SOURCE_NEAR_DIGITAL_RAIL')
    if any(b['touches_edge'] for b in good): reasons.append('SOURCE_AT_EDGE')
    if any((b['peak']-bg)/sigma<6 for b in good): reasons.append('LOW_PEAK_CONTRAST')
    if any(math.hypot(b['x']-c['x'],b['y']-c['y'])<10 for i,b in enumerate(good) for c in good[i+1:]):
        reasons.append('SOURCES_TOO_CLOSE_FOR_D1')
    return dict(accepted=not reasons,reasons=reasons,threshold_y=threshold,background_y=bg,
                background_sigma=sigma,detected=len(good),expected=expected,
                minimum_peak_contrast=min(((b['peak']-bg)/sigma for b in good),default=0),blobs_pc=blobs)


def assess_series(rows):
    reasons=[]; all_good=all(r['field_quality']['accepted'] for r in rows)
    if not all_good: reasons.append('NOT_ALL_FIVE_CAPTURES_ACCEPTED')
    jitter=None
    if all_good:
        refs=[[b['x'],b['y']] for b in rows[0]['field_quality']['blobs_pc'] if b['accepted']]
        tracks=[[] for _ in refs]
        for row in rows:
            quality=row['field_quality']; image=Image.open(row['_absolute_image'])
            blobs,labels=components(image,quality['threshold_y'])
            result=associations(blobs,labels,refs,8)
            if result['correct']!=len(refs): reasons.append('TEMPORAL_ASSOCIATION_LOST');break
            by_label={b['label']:b for b in blobs}
            for m in result['matches']:
                b=by_label[m['label']]; tracks[m['reference']].append([b['x'],b['y']])
        if all(len(t)==len(rows) for t in tracks):
            jitter=max(float(np.linalg.norm(np.std(np.array(t),axis=0))) for t in tracks)
            if jitter>1.0: reasons.append('CENTROID_TEMPORAL_JITTER_GT_1PX')
    return dict(accepted=not reasons,reasons=sorted(set(reasons)),n_frames=len(rows),
                max_temporal_radial_std_pc_px=jitter,
                minimum_peak_contrast=min(r['field_quality']['minimum_peak_contrast'] for r in rows))


class AutonomousBench(Bench):
    def __init__(self,output,port):
        super().__init__(output,port)
        self.decisions=[];self.running=False
        self.viewport=None
        self.meta.update(mode='AUTONOMOUS_EXPLORATORY_D1_D3',focus_status='unresolved; user explicitly requested proceeding without further focus adjustment',
                         setup={'native_resolution':[2560,1440],'hdr_off':True,'monitor_brightness_osd':0,'distance_mm':250,
                                'authority':'user confirmation in this chat','refresh_hz':None},
                         protocol_change='User requested five equal, well separated sources for D1 instead of one isolated source.',
                         d1_field_monitor_px=FIELD,control_inter_command_gap_seconds=.25,
                         controller_limit='Paced commands succeeded previously; original runtime timeout cause unresolved.',
                         acceptance={'D1':'5/5 frames with exactly 5 sources, no source peak >=250, contrast/noise >=6, no edge truncation, max radial temporal std <=1 camera pixel',
                                     'D2':'5/5 confirmations at center and displaced position, one source, no flags or peak >=250, radial temporal std <=0.5 camera pixel; PC outputs only',
                                     'D3':'Report correct/expected, merged, omitted and false sources at every tested separation/noise. Close-pair failure is a measured limit.',
                                     'scope':'exploratory local bench; not FAT or independent absolute centroid accuracy'})
        self.publish('campo_D1_preparado',points=FIELD,diameter=8)
        self.update('LISTO_AUTOMATICO','Generador de cinco estrellas preparado; pendiente iniciar la adquisicion.')
        self.persist()

    def persist(self):
        write_json(self.output/'manifest.json',self.meta)
        write_json(self.output/'measurements.json',self.rows)
        write_json(self.output/'decisions.json',self.decisions)

    def decide(self,stage,result,reason,**data):
        self.decisions.append(dict(time_utc=datetime.now(timezone.utc).isoformat(),stage=stage,result=result,reason=reason,**data))
        self.persist()

    def publish(self,name,**kwargs):
        image,meta=pattern(**kwargs); identity=uuid.uuid4().hex
        scene=dict(id=identity,name=name,**meta)
        directory=self.output/'patterns';directory.mkdir(exist_ok=True)
        image.save(directory/f'{identity}.png');write_json(directory/f'{identity}.json',scene)
        stream=io.BytesIO();image.save(stream,format='PNG')
        with self.lock: self.png=stream.getvalue();self.state['scene']=scene
        return scene

    def wait_scene(self,scene):
        end=time.monotonic()+180
        while time.monotonic()<end:
            self.check()
            with self.lock:
                ready=self.ack.get('id')==scene['id'] and self.display_acceptable(self.ack) and time.monotonic()-self.ack_time<2
            if ready: self.wait(1);return scene
            self.wait(.1)
        raise TimeoutError('Patron sin confirmacion visible y estable en el G5')

    def display_acceptable(self,data):
        size=tuple(data.get(k,0) for k in ('width','height','dpr'))
        return bool(data.get('visible') and all(isinstance(v,(int,float)) and math.isfinite(v) and v>0 for v in size)
                    and (self.viewport is None or size==self.viewport))

    def require_display(self,scene):
        with self.lock:
            if self.ack.get('id')!=scene['id'] or not self.display_acceptable(self.ack) or time.monotonic()-self.ack_time>2:
                raise RuntimeError('Patron sin confirmacion visible, reciente y con escala estable')
            return self.display_faults

    def scene(self,name,**kwargs): return self.wait_scene(self.publish(name,**kwargs))

    def capture(self,*args,**kwargs):
        row,image=super().capture(*args,**kwargs)
        row['_absolute_image']=str(self.output/row['image'])
        with self.lock: row['display']=dict(self.ack)
        row['stimulus_coordinate_system']='2560x1440 design pixels; actual monitor scaling in manifest.display_geometry'
        geometry=self.meta.get('display_geometry')
        if geometry:
            sx,sy=geometry['scale_x'],geometry['scale_y']
            row['displayed_stimulus']=dict(points_device_px=[[(x+.5)*sx-.5,(y+.5)*sy-.5] for x,y in row['scene']['points']],
                diameter_device_px_xy=[row['scene']['diameter_monitor_px']*sx,row['scene']['diameter_monitor_px']*sy])
        return row,image

    def series(self,condition,scene,registers,stage,n=5):
        condition=f'A{getattr(self,"flow_attempt",1)}_{condition}'
        rows=[]
        for i in range(n):
            self.update(stage,f'{condition}: captura {i+1}/{n}')
            rows.append(self.capture(condition,scene,registers,stage,i+1))
        observed=self.camera.snapshot()
        if observed!=registers: raise RuntimeError('CONTROL_DRIFT: cambiaron registros durante la serie')
        self.persist();return rows

    def calibration(self,regs,name):
        rows=[];black=[]
        for level in (0,64,128,192,255):
            scene=self.scene(f'{name}_RGB_{level}',flat=level)
            for row,image in self.series(f'RGB{level}',scene,regs,name,n=3):
                a=np.asarray(image); patch=a[105:135,145:175]
                rows.append(dict(level=level,patch_mean=float(patch.mean()),patch_max=int(patch.max()),id=row['id']))
                if level==0: black.append(a)
        curve=response_curve(rows)
        temporal=float(np.std(np.stack(black).astype(float),axis=0).mean())
        threshold=int(math.ceil(max(stats(a)['p999'] for a in black)+max(5,5*temporal)))
        curve.update(rows=rows,temporal_black_noise_std=temporal,threshold_y=threshold,
                     protocol_note='Five stimulus levels with three repetitions per level for this autonomous run.')
        write_json(self.output/f'{name}.json',curve)
        if curve['span_y']<10 or not curve['monotonic_with_2dn_tolerance'] or threshold>=245:
            raise ValueError('CAPTURE_RESPONSE: respuesta RGB-Y insuficiente o no monotona')
        self.meta[name]=curve;self.persist();return threshold

    def run_d1(self,base):
        for attempt,diameter in enumerate((8,12,16),1):
            exposures=sorted({max(1,min(510,round(base*f))) for f in (.25,.5,1)})
            while len(exposures)<3: exposures.append(max(exposures)+1)
            conditions=[(e,g) for e in exposures for g in (0,16)]
            order=np.random.default_rng(20261110+attempt).permutation(6).tolist()
            candidates=[]
            self.decide('D1','ATTEMPT','Evaluate fixed five-source field',attempt=attempt,diameter_monitor_px=diameter,conditions=conditions,order=order)
            for i in order:
                e,g=conditions[i];name=f'D1A{attempt}_C{i+1:02d}'
                regs=self.camera.profile(e,g);self.wait(.7)
                scene=self.scene(name,points=FIELD,diameter=diameter)
                measured=self.series(name,scene,regs,'D1')
                rows=[]
                for row,image in measured:
                    row['field_quality']=field_quality(image);rows.append(row)
                result=assess_series(rows)
                self.decide('D1','ACCEPT' if result['accepted'] else 'REJECT','Automatic field evaluation',condition=name,**result)
                if result['accepted']:
                    candidates.append(dict(condition=name,exposure=e,gain=g,diameter=diameter,assessment=result))
            if candidates:
                chosen=max(candidates,key=lambda c:c['assessment']['minimum_peak_contrast'])
                regs=self.camera.profile(chosen['exposure'],chosen['gain'])
                self.meta['selected_D1']=chosen;self.persist()
                self.decide('D1','PASS','Strongest minimum source contrast among all accepted conditions',selection=chosen)
                return regs,chosen
            self.decide('D1','ITERATE','No acceptable profile; increase source diameter on next attempt',attempt=attempt)
        raise ValueError('D1_LIMIT: no se obtuvieron cinco fuentes validas con los tamanos/perfiles ensayados')

    def geometry(self,regs,threshold):
        screen=[];camera=[]
        for i,(dx,dy) in enumerate(( (x,y) for y in (-60,0,60) for x in (-60,0,60) )):
            point=(CENTER[0]+dx,CENTER[1]+dy)
            scene=self.scene(f'G{i}',points=[point],diameter=self.meta['selected_D1']['diameter'])
            centers=[]
            for row,image in self.series(f'G{i}',scene,regs,'GEOMETRIA',n=3):
                blobs,_=components(image,threshold)
                valid=[b for b in blobs if b['accepted'] and not b['touches_edge']]
                row['blobs_pc']=blobs
                if len(valid)!=1: raise ValueError('D2_GEOMETRY: una fuente aislada no se distingue; revisar D1')
                centers.append([valid[0]['x'],valid[0]['y']])
            screen.append(point);camera.append(np.mean(centers,axis=0).tolist())
        geometry=fit_geometry(screen,camera,[0,1,2,3,6,8])
        geometry.update(screen_points=screen,camera_centers=camera)
        write_json(self.output/'geometry.json',geometry)
        if geometry['heldout_max_px']>1: raise ValueError('D2_GEOMETRY_LIMIT: comprobacion local mayor de 1 pixel; no atribuir exactitud')
        self.meta['geometry']=geometry;self.persist();return geometry

    def run_d2(self,regs,threshold,geometry):
        sizes=sorted(set([4,8,12,self.meta['selected_D1']['diameter']]))
        collected=[]
        for i,(diameter,dx) in enumerate(( (d,x) for d in sizes for x in (0,50) )):
            points=[(CENTER[0]+dx,CENTER[1])];expected=project(points,geometry)
            scene=self.scene(f'D2_P{i+1:02d}',points=points,diameter=diameter)
            for row,image in self.series(f'P{i+1:02d}',scene,regs,'D2'):
                row.update(diameter_monitor_px=diameter,offset_monitor_px=dx,expected_camera_px=expected)
                collected.append(row)
        # Threshold adjustment is explicitly exploratory; fresh confirmations follow.
        for candidate_threshold in sorted(set([threshold,max(1,threshold-3)]),reverse=True):
            candidates=[]
            for diameter in sizes:
                rows=[r for r in collected if r['diameter_monitor_px']==diameter]
                valid=True;jitters=[]
                for row in rows:
                    image=Image.open(row['_absolute_image']);blobs,labels=components(image,candidate_threshold)
                    row['blobs_pc']=blobs;row['association']=associations(blobs,labels,row['expected_camera_px'],5)
                    row['point']=measure(image,center=tuple(round(v) for v in row['expected_camera_px'][0]),radius=15,threshold=candidate_threshold)
                    if row['association']['correct']!=1 or row['association']['false_components'] or row['point']['flags'] or row['statistics']['max']>=250: valid=False
                for dx in (0,50):
                    subset=[r for r in rows if r['offset_monitor_px']==dx]
                    if any(r['point']['centroid_x'] is None for r in subset): valid=False;continue
                    sd=np.std([[r['point']['centroid_x'],r['point']['centroid_y']] for r in subset],axis=0)
                    jitters.append(float(np.linalg.norm(sd)))
                if jitters and max(jitters)>.5:valid=False
                self.decide('D2','CANDIDATE_ACCEPT' if valid else 'CANDIDATE_REJECT','Size and threshold exploration',diameter_monitor_px=diameter,threshold_y=candidate_threshold,jitter_radial_pc_px=jitters)
                if valid:candidates.append(dict(diameter=diameter,threshold=candidate_threshold,max_jitter=max(jitters)))
            if candidates:
                selected=min(candidates,key=lambda c:c['max_jitter'])
                for dx in (0,50):
                    points=[(CENTER[0]+dx,CENTER[1])];expected=project(points,geometry)
                    scene=self.scene(f'D2_confirm_{dx}',points=points,diameter=selected['diameter'])
                    centers=[]
                    for row,image in self.series(f'CONFIRM_{dx}',scene,regs,'D2_CONFIRM'):
                        blobs,labels=components(image,selected['threshold']);assoc=associations(blobs,labels,expected,5)
                        row.update(blobs_pc=blobs,association=assoc,expected_camera_px=expected)
                        if assoc['correct']!=1 or assoc['false_components'] or row['statistics']['max']>=250:
                            raise ValueError('D2_CONFIRM_LIMIT: parametros no confirmados en capturas nuevas')
                        b=next(b for b in blobs if b['label']==assoc['matches'][0]['label']);centers.append([b['x'],b['y']])
                    if float(np.linalg.norm(np.std(centers,axis=0)))>.5:raise ValueError('D2_CONFIRM_LIMIT: dispersion temporal mayor de 0.5 pixel')
                self.meta['selected_D2']=selected;self.decide('D2','PASS','Confirmed on ten fresh captures; no FPGA accuracy claim',selection=selected)
                return selected
            self.decide('D2','ITERATE','Try predeclared lower threshold on existing exploratory frames')
        raise ValueError('D2_LIMIT: no size/threshold met the exploratory criteria')

    def run_d3(self,regs,selection,geometry):
        scale=float(np.linalg.norm(np.array(geometry['matrix'])[0]));gate=max(1.,min(2.,8*scale*.4))
        self.meta['D3_gate_camera_px']=gate
        for i,(sep,noise) in enumerate(( (s,n) for s in (8,16,24) for n in (0,8) )):
            points=[(CENTER[0]+k*sep,CENTER[1]) for k in (-2,-1,0,1,2)];expected=project(points,geometry)
            scene=self.scene(f'D3_R{i+1:02d}',points=points,diameter=selection['diameter'],noise=noise,seed=20261110+i)
            summary=dict(correct=0,expected=0,fused_sources=0,omissions=0,false_components=0)
            for row,image in self.series(f'R{i+1:02d}',scene,regs,'D3'):
                blobs,labels=components(image,selection['threshold']);assoc=associations(blobs,labels,expected,gate)
                row.update(blobs_pc=blobs,association=assoc,expected_camera_px=expected)
                for k in summary:summary[k]+=assoc[k]
            passed=summary['correct']==summary['expected'] and summary['false_components']==0
            overlaps=scene['overlap_requested']
            result='STIMULUS_OVERLAP' if overlaps else ('RESOLVED' if passed else 'OBSERVED_LIMIT')
            self.decide('D3',result,'Overlapping design disks are not an optical resolution measurement' if overlaps else
                        'Record each tested separation/noise; preserve failed conditions',condition=f'R{i+1:02d}',
                        separation_design_px=sep,separation_device_px=sep*self.meta['display_geometry']['scale_x'],
                        diameter_design_px=selection['diameter'],nominal_sources_overlap=overlaps,noise_sigma_rgb=noise,**summary)
        self.decide('D3','COMPLETE','All six conditions recorded; distinguish measured resolution limits from acquisition failures')

    def execute_flow(self):
        self.viewport=None
        scene=self.wait_scene(self.state['scene'])
        with self.lock:
            self.viewport=tuple(self.ack[k] for k in ('width','height','dpr'))
            w,h,dpr=self.viewport
            self.meta['display_geometry']=dict(viewport_css_px=[w,h],device_pixel_ratio=dpr,
                displayed_device_px=[w*dpr,h*dpr],scale_x=w*dpr/SCREEN[0],scale_y=h*dpr/SCREEN[1],
                fullscreen=self.ack.get('fullscreen'),authorization='User explicitly accepted current browser resolution and scaling',
                interpretation='Design pattern stretched to viewport; source diameter scales independently on each axis. Not native-pixel metrology.')
        self.persist()
        self.camera=PacedCamera(self.port,self.output);self.camera.handshake()
        self.require_display(scene)
        payload,messages=self.camera.capture()
        name=f'pilot_field_A{self.flow_attempt}'
        Image.frombytes('L',(320,240),payload).save(self.output/f'{name}.png');(self.output/f'{name}.raw').write_bytes(payload)
        self.meta['pilot_messages']=messages
        before=self.camera.snapshot();regs=self.camera.freeze();self.meta.update(initial_registers=before,frozen_registers=regs)
        self.meta['initial_mode']='automatic' if before['13']&5 else 'manual'
        base=min(510,max(1,decode_profile(regs)['exposure_code']))
        self.calibration(regs,f'CAL_INICIAL_A{self.flow_attempt}')
        regs,d1=self.run_d1(base)
        threshold=self.calibration(regs,f'CAL_D1_SELECCIONADO_A{self.flow_attempt}')
        geometry=self.geometry(regs,threshold)
        selected=self.run_d2(regs,threshold,geometry)
        self.run_d3(regs,selected,geometry)

    def recover_control(self):
        if self.camera:self.camera.close();self.camera=None
        self.update('RECUPERANDO_D1','Reiniciando control/captura; se conserva toda la evidencia anterior.')
        log=self.output/f'recovery_before_A{self.flow_attempt+1}.log'
        with log.open('wb') as stream:
            script=str(ROOT/'scripts/load_capture.tcl').replace("'","''")
            result=subprocess.run(['C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe','-NoProfile','-NonInteractive','-Command',
                                   "& 'C:\\AMDDesignTools\\2025.2\\Vitis\\bin\\xsct.bat' '"+script+"'"],stdout=stream,stderr=subprocess.STDOUT,timeout=60,
                                   creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        if result.returncode:raise RuntimeError('No se pudo reiniciar el control; ver log de recuperacion')
        self.wait(1)
        self.publish('campo_D1_tras_recuperacion',points=FIELD,diameter=8)

    def run(self):
        if self.running:return
        self.running=True
        try:
            self.update('PREPARANDO','Verificando patron y control; se conserva el enfoque actual.')
            for self.flow_attempt in range(1,4):
                try:
                    self.execute_flow();break
                except (RuntimeError,TimeoutError) as exc:
                    self.decide(self.state['phase'],'RETURN_D1','Capture/control failure requires a new D1 branch',flow_attempt=self.flow_attempt,error=repr(exc))
                    if self.stop.is_set() or self.flow_attempt==3:raise
                    self.recover_control()
            self.persist();self.report();self.update('COMPLETO_D1_D3','DoE terminado hasta separacion. Evidencias y limites conservados localmente.')
        except Exception as exc:
            self.meta['failure']=repr(exc)
            category=('CAPTURE_OR_CONTROL' if isinstance(exc,(RuntimeError,TimeoutError)) else
                      'PARAMETER_OR_OPTICAL_LIMIT' if isinstance(exc,ValueError) else 'CONTROLLER_SOFTWARE')
            self.decide(self.state['phase'],'STOP_REVIEW',str(exc),category=category)
            self.report();self.update('DETENIDO_CON_EVIDENCIA',str(exc))
        finally:
            if self.camera:self.camera.close()


def handler_for(bench):
    base=make_handler(bench)
    class Handler(base):
        def do_GET(self):
            if self.path=='/api/display_state':
                with bench.lock:return self.send(dict(bench.ack,age_seconds=time.monotonic()-bench.ack_time))
            return super().do_GET()
        def do_POST(self):
            if self.path=='/api/display':
                try:
                    if self.headers.get('Origin') not in (None,f'http://{self.headers.get("Host")}'):
                        raise ValueError('Origen no permitido')
                    length=int(self.headers.get('Content-Length','0'))
                    if not 0<length<100000: raise ValueError('Tamano no permitido')
                    data=json.loads(self.rfile.read(length))
                    with bench.lock:
                        if not bench.display_acceptable(data) or data.get('id')!=bench.state['scene']['id']:
                            bench.display_faults+=1
                        bench.ack=data;bench.ack_time=time.monotonic()
                    return self.send({'ok':True})
                except (ValueError,TypeError) as exc:return self.send({'error':str(exc)},status=400)
            if self.path=='/api/auto/start':
                if self.headers.get('X-Bench-Token')!=bench.token:return self.send({'error':'Token invalido'},status=400)
                if bench.running:return self.send({'error':'Ya iniciado'},status=400)
                threading.Thread(target=bench.run,daemon=True).start();return self.send({'ok':True})
            return super().do_POST()
    return Handler


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--port',default='COM3');p.add_argument('--http-port',type=int,default=8765)
    a=p.parse_args();clock=datetime.now(timezone(timedelta(hours=-5)))
    out=ROOT/'build/ensayos_doe'/clock.strftime('%Y%m%d_%H%M%S_autonomo')
    bench=AutonomousBench(out,a.port)
    bench.meta['autonomous_script_sha256']=__import__('hashlib').sha256(Path(__file__).read_bytes()).hexdigest();bench.persist()
    print('DOE_OUTPUT='+str(out),flush=True)
    ThreadingHTTPServer(('127.0.0.1',a.http_port),handler_for(bench)).serve_forever()


if __name__=='__main__':main()
