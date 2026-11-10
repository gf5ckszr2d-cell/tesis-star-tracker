"""Synthetic tests. None of these data are physical camera measurements."""
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image, ImageFilter
import banco_doe as bank
from doe_analysis import components, associations, fit_geometry, project, response_curve
from doe_device import decode_profile


class AnalysisTest(unittest.TestCase):
    def test_y_weighted_eight_connected_and_area(self):
        a=np.zeros((10,10),dtype=np.uint8); a[2,2]=60; a[3,3]=120; a[8,8]=100
        blobs,labels=components(a,45)
        self.assertEqual(len(blobs),2)
        self.assertAlmostEqual(blobs[0]['x'],8/3)
        self.assertTrue(blobs[0]['accepted']); self.assertFalse(blobs[1]['accepted'])

    def test_fusion_omission_false_and_one_to_one(self):
        a=np.zeros((20,30),dtype=np.uint8)
        a[5,3:10]=100; a[12,12:14]=100; a[16,22:24]=100
        blobs,labels=components(a,45)
        r=associations(blobs,labels,[(4,5),(8,5),(12.5,12),(25,2)],2)
        self.assertEqual([r[k] for k in ('correct','fused_sources','fusion_components','omissions','false_components')],[1,2,1,1,1])
        r=associations(blobs,labels,[(12.5,12),(13,12)],2)
        self.assertEqual(r['fused_sources'],2)

    def test_affine_reference_and_holdout(self):
        screen=[(x,y) for y in (-60,0,60) for x in (-60,0,60)]
        camera=[[160-.6*x+.01*y,120+.02*x+.7*y] for x,y in screen]
        g=fit_geometry(screen,camera,[0,1,2,3,6,8])
        self.assertLess(g['heldout_max_px'],1e-10)
        self.assertAlmostEqual(project([(50,0)],g)[0][0],130)

    def test_scene_seed_range_flat_and_overlap(self):
        a,meta=bank.pattern(points=[bank.CENTER,(bank.CENTER[0]+2,bank.CENTER[1])],diameter=8,noise=8,seed=7)
        b,_=bank.pattern(points=[bank.CENTER,(bank.CENTER[0]+2,bank.CENTER[1])],diameter=8,noise=8,seed=7)
        self.assertEqual(a.tobytes(),b.tobytes())
        self.assertTrue(meta['overlap_requested'])
        self.assertGreater(meta['achieved_background_mean'],0)
        flat,_=bank.pattern(flat=128)
        self.assertEqual(flat.getextrema(),(128,128))

    def test_display_rejects_wrong_size_hidden_window(self):
        good=dict(width=2560,height=1440,dpr=1,fullscreen=True,visible=True)
        self.assertTrue(bank.display_ok(good))
        self.assertFalse(bank.display_ok(dict(good,width=1920)))
        self.assertFalse(bank.display_ok(dict(good,visible=False)))
        self.assertFalse(bank.display_ok(dict(good,fullscreen=False)))
        self.assertTrue(bank.display_ok(dict(good,width=2048,height=1152,dpr=1.25)))

    def test_register_bit_fields(self):
        self.assertEqual(decode_profile({'07':3,'10':0xAB,'04':0xF2,'03':0xC0,'00':0x35}),
                         dict(exposure_code=(3<<10)|(0xAB<<2)|2,gain_code=0x335))

    def test_curve_does_not_assume_y_equals_rgb(self):
        curve=response_curve([dict(level=l,patch_mean=7+.5*l) for l in (0,128,255) for _ in range(3)])
        self.assertEqual(curve['black_y'],7)
        self.assertEqual(curve['white_y'],134.5)


class FakeCamera:
    bench=None
    def __init__(self,port,output):
        self.regs={f'{r:02X}':0 for r in __import__('doe_device').REGISTERS}
        self.regs.update({'0A':0x76,'0B':0x73,'10':37,'04':2,'13':0x8F})
        self.rng=np.random.default_rng(10)
    def handshake(self): pass
    def capture(self):
        scene=FakeCamera.bench.state['scene']
        image,_=bank.pattern(points=scene['points'],diameter=scene['diameter_monitor_px'],level=scene['level_rgb'],
                             noise=scene['noise_sigma_before_clipping'],seed=scene['seed'],flat=scene['flat'])
        optical=image.crop((1040,540,1520,900)).resize((320,240),Image.Resampling.BOX).filter(ImageFilter.GaussianBlur(.55))
        profile=decode_profile(self.regs)
        a=np.asarray(optical,float)*profile['exposure_code']*.004*(1+profile['gain_code']/16)
        a=np.clip(np.rint(3+a+self.rng.normal(0,.5,(240,320))),0,255).astype(np.uint8)
        return a.tobytes(),['ARM captura: OK lineas=240 bytes_min=640 bytes_max=640 pixeles=76800 primera_linea_mala=ninguna','OK imagen 76800 checksum; esperando BTN1']
    def snapshot(self): return dict(self.regs)
    def freeze(self): self.regs['13']&=~7; return self.snapshot()
    def profile(self,e,g):
        self.regs.update({'04':e&3,'10':(e>>2)&255,'07':e>>10,'03':(g>>8)<<6,'00':g&255})
        return self.snapshot()
    def close(self): pass


class FastBench(bank.Bench):
    def wait(self,seconds): self.check()
    def require_display(self,scene): return 0
    def scene(self,name,**kwargs):
        scene=dict(id=name,name=name,points=list(kwargs.get('points',[])),diameter_monitor_px=kwargs.get('diameter',8),
                   level_rgb=kwargs.get('level',255),noise_sigma_before_clipping=kwargs.get('noise',0),seed=kwargs.get('seed',0),flat=kwargs.get('flat'))
        self.state['scene']=scene
        return scene
    def update(self,phase,message):
        self.state.update(phase=phase,message=message)
        if phase=='ENFOQUE_VISUAL': self.accept_visual({'focus_confirmed':True})
        if phase=='CRITERIO_VISUAL_D1':
            self.accept_visual(dict(records=[dict(id=r['id'],complete=True,distinct=True,contour=True) for r in self.d1],
                                    selected='C01',reason='SYNTHETIC TEST: not an operator judgement'))


class PipelineTest(unittest.TestCase):
    def test_full_synthetic_d1_d3_gates_and_counts(self):
        with tempfile.TemporaryDirectory(dir=bank.ROOT/'build') as tmp:
            bench=FastBench(Path(tmp)/'SYNTHETIC_ONLY','FAKE',physical=False)
            FakeCamera.bench=bench
            with patch.object(bank,'Camera',FakeCamera): bench.run()
            self.assertEqual(bench.state['phase'],'COMPLETO_D1_D3',bench.state)
            for stage in ('D1','D2','D3'):
                self.assertEqual(sum(r['stage']==stage for r in bench.rows),30)
            self.assertFalse(json.loads((bench.output/'manifest.json').read_text(encoding='utf-8'))['physical'])
            self.assertTrue((bench.output/'visual_D1.json').is_file())
            self.assertTrue((bench.output/'report.html').is_file())
            self.assertTrue((bench.output/'measurements.csv').is_file())


if __name__=='__main__': unittest.main()
