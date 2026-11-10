"""Expedited physical D1 confirmation, D2 confirmation and complete D3 matrix.
Reuses explicitly identified D1/D2 exploratory evidence. No new fine calibration.
"""
import json,time,threading
from pathlib import Path
from datetime import datetime
from http.server import ThreadingHTTPServer
import numpy as np
from PIL import Image
from banco_doe import ROOT,write_json
from doe_autonomo import AutonomousBench,PacedCamera,FIELD,field_quality,assess_series,handler_for
from doe_analysis import components,associations,fit_geometry,project
from medir_estrella import measure

PREVIOUS=ROOT/'build/ensayos_doe/20261110_135729_autonomo'

class ClosingBench(AutonomousBench):
    def run(self):
        if self.running:return
        self.running=True;self.flow_attempt=1
        try:
            self.meta.update(mode='LAP_D1_D3_CLOSING_CAMPAIGN',prior_evidence=str(PREVIOUS),
                protocol_change='User expedited closure through D3 and deferred fine calibration. D1 matrix and D2 size exploration reuse prior physical evidence. New five-frame D1, ten-frame D2 confirmations and full 30-frame D3 matrix.',
                fine_calibration='Deferred outside this acceptance scope',
                transport_mitigation='PC RX queue requested 262144 bytes; capture timeout 60 s. Root cause of earlier truncated transfer remains unresolved.')
            scene=self.wait_scene(self.state['scene'])
            with self.lock:
                self.viewport=tuple(self.ack[k] for k in ('width','height','dpr'));w,h,dpr=self.viewport
                self.meta['display_geometry']=dict(viewport_css_px=[w,h],device_pixel_ratio=dpr,displayed_device_px=[w*dpr,h*dpr],
                    scale_x=w*dpr/2560,scale_y=h*dpr/1440,fullscreen=self.ack.get('fullscreen'),authorization='User accepts scaled current viewport')
            self.camera=PacedCamera(self.port,self.output);self.camera.handshake()
            payload,messages=self.camera.capture()
            Image.frombytes('L',(320,240),payload).save(self.output/'initialization_only.png')
            (self.output/'initialization_only.raw').write_bytes(payload)
            self.camera.freeze();regs=self.camera.profile(384,16)
            self.meta['frozen_registers']=regs;self.persist()
            rows=[]
            for row,image in self.series('D1_CONFIRM',scene,regs,'D1',n=5):
                row['field_quality']=field_quality(image);rows.append(row)
            result=assess_series(rows)
            self.decide('D1','PASS' if result['accepted'] else 'NOT_ACCEPTED','Fresh five-source confirmation; prior six-profile matrix retained separately',**result)
            if not result['accepted']:raise ValueError('D1_CONFIRM: no five-source confirmation')
            self.meta['selected_D1']=dict(exposure=384,gain=16,diameter=8,origin=str(PREVIOUS))
            # Current-viewport affine map: four corners fit, center held out.
            camera=[]
            for row in rows:
                blobs=sorted((b for b in row['field_quality']['blobs_pc'] if b['accepted']),key=lambda b:b['y'])
                top=sorted(blobs[:2],key=lambda b:b['x']);bottom=sorted(blobs[-2:],key=lambda b:b['x'])
                camera.append([[blobs[2]['x'],blobs[2]['y']]]+[[b['x'],b['y']] for b in top+bottom])
            geometry=fit_geometry(FIELD,np.mean(camera,axis=0).tolist(),[1,2,3,4])
            geometry['scope']='Four field corners fitted, one center held out; local empirical PC map only'
            if geometry['heldout_max_px']>1:raise ValueError('Current local map exceeds 1 px')
            self.meta['geometry']=geometry;write_json(self.output/'geometry.json',geometry)
            old=json.loads((PREVIOUS/'measurements.json').read_text(encoding='utf-8'))
            candidates=[]
            for diameter in (4,8):
                subset=[r for r in old if r['stage']=='D2' and r['condition'] in
                    (('A1_P01','A1_P02') if diameter==4 else ('A1_P03','A1_P04'))]
                valid=len(subset)==10;jitters=[]
                for row in subset:
                    image=Image.open(PREVIOUS/row['image']);point=measure(image,center=tuple(round(v) for v in row['expected_camera_px'][0]),radius=15,threshold=9)
                    if point['flags'] or row['statistics']['max']>=250:valid=False
                    row['point']=point
                for condition in sorted({r['condition'] for r in subset}):
                    points=[r['point'] for r in subset if r['condition']==condition]
                    if any(p['centroid_x'] is None for p in points):valid=False;continue
                    jitters.append(float(np.linalg.norm(np.std([[p['centroid_x'],p['centroid_y']] for p in points],axis=0))))
                valid=valid and len(jitters)==2 and max(jitters)<=.5
                self.decide('D2','PRIOR_CANDIDATE_ACCEPT' if valid else 'PRIOR_CANDIDATE_REJECT','Offline analysis of ten existing physical frames',diameter=diameter,jitters=jitters,frame_ids=[r['id'] for r in subset])
                if valid:candidates.append(dict(diameter=diameter,threshold=9,max_jitter=max(jitters)))
            if not candidates:raise ValueError('D2: no valid prior size candidate')
            selected=min(candidates,key=lambda c:c['max_jitter']);valid=True
            for dx in (0,50):
                from banco_doe import CENTER
                points=[(CENTER[0]+dx,CENTER[1])];expected=project(points,geometry)
                scene=self.scene(f'D2_CONFIRM_{dx}',points=points,diameter=selected['diameter']);centers=[]
                for row,image in self.series(f'CONFIRM_{dx}',scene,regs,'D2_CONFIRM'):
                    blobs,labels=components(image,9);association=associations(blobs,labels,expected,5)
                    point=measure(image,center=tuple(round(v) for v in expected[0]),radius=15,threshold=9)
                    row.update(blobs_pc=blobs,association=association,point=point,expected_camera_px=expected)
                    if point['flags'] or association['correct']!=1 or association['false_components'] or row['statistics']['max']>=250:valid=False
                    if point['centroid_x'] is not None:centers.append([point['centroid_x'],point['centroid_y']])
                if len(centers)!=5 or float(np.linalg.norm(np.std(centers,axis=0)))>.5:valid=False
            self.meta['selected_D2']=selected
            self.decide('D2','PASS' if valid else 'NOT_ACCEPTED','Ten fresh physical confirmation frames; dispersion limit 0.5 camera pixel',selection=selected)
            # Characterize separation even if D2 acceptance fails. Preserve that verdict.
            self.run_d3(regs,selected,geometry)
            self.persist();self.report();self.update('COMPLETO_D1_D3','LAP physical characterization closed through D3')
        except Exception as exc:
            self.meta['failure']=repr(exc);self.decide(self.state['phase'],'STOP_REVIEW',repr(exc))
            self.persist()
            try:self.report()
            finally:self.update('DETENIDO_CON_EVIDENCIA',str(exc))
        finally:
            if self.camera:self.camera.close()

if __name__=='__main__':
    out=ROOT/'build/ensayos_doe'/datetime.now().strftime('%Y%m%d_%H%M%S_LAP_cierre')
    bench=ClosingBench(out,'COM3');print('DOE_OUTPUT='+str(out),flush=True)
    ThreadingHTTPServer(('127.0.0.1',8765),handler_for(bench)).serve_forever()
