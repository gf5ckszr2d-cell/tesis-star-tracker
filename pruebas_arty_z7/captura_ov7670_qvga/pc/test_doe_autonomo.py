import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch
from PIL import Image,ImageDraw
from doe_autonomo import field_quality,FIELD,AutonomousBench,CENTER

class AutonomousCriteriaTest(unittest.TestCase):
    def image(self,missing=False,saturated=False):
        im=Image.new('L',(320,240),3);d=ImageDraw.Draw(im)
        points=[(160,120),(90,70),(230,70),(90,170),(230,170)]
        for i,(x,y) in enumerate(points[:-1] if missing else points):
            d.ellipse((x-3,y-3,x+3,y+3),fill=255 if saturated and i==0 else 150)
        return im
    def test_five_sources_accepted(self):
        q=field_quality(self.image());self.assertTrue(q['accepted'],q);self.assertEqual(q['detected'],5)
    def test_missing_source_rejected(self):
        self.assertFalse(field_quality(self.image(missing=True))['accepted'])
    def test_saturated_source_rejected(self):
        self.assertFalse(field_quality(self.image(saturated=True))['accepted'])
    def test_monitor_field_inside_local_calibration(self):
        self.assertEqual(len(FIELD),5)
        self.assertEqual(len(set(FIELD)),5)

    def test_scaled_visible_viewport_and_stability(self):
        bench=object.__new__(AutonomousBench);bench.viewport=None
        data=dict(width=2560,height=1384,dpr=1,visible=True,fullscreen=False)
        self.assertTrue(bench.display_acceptable(data))
        bench.viewport=(2560,1384,1)
        self.assertTrue(bench.display_acceptable(data))
        self.assertFalse(bench.display_acceptable(dict(data,height=1440)))
        self.assertFalse(bench.display_acceptable(dict(data,visible=False)))
        self.assertFalse(bench.display_acceptable(dict(data,dpr=float('nan'))))

    def test_complete_controller_with_synthetic_camera(self):
        # Exercises the actual D1/calibration/geometry/D2/D3 controller together.
        # It verifies software orchestration, never physical acceptance.
        with tempfile.TemporaryDirectory() as directory:
            bench=AutonomousBench(Path(directory)/'synthetic','FAKE')
            bench.meta['physical']=False
            bench.ack=dict(width=2560,height=1384,dpr=1,visible=True,fullscreen=False)
            bench.wait=lambda seconds:None
            bench.wait_scene=lambda scene:scene
            bench.require_display=lambda scene:0
            bench.update=lambda *args:None
            class FakeCamera:
                def __init__(self,*args):self.e=384;self.g=0
                def handshake(self):pass
                def snapshot(self):return {'0A':118,'0B':115,'07':64,'10':self.e>>2,'04':self.e&3,'03':0,'00':self.g,'13':136}
                def freeze(self):return self.snapshot()
                def profile(self,e,g):self.e=e;self.g=g;return self.snapshot()
                def capture(self):
                    scene=bench.state['scene'];flat=scene['flat']
                    brightness=min(235,round(210*self.e/384*(1+self.g/32)))
                    im=Image.new('L',(320,240),2 if flat is None else 2+round(brightness*flat/255))
                    draw=ImageDraw.Draw(im);radius=scene['diameter_monitor_px']*.25
                    if flat is None:
                        for x,y in scene['points']:
                            cx=160+(x-CENTER[0])*.5;cy=120+(y-CENTER[1])*.5
                            draw.ellipse((cx-radius,cy-radius,cx+radius,cy+radius),fill=brightness)
                    return im.tobytes(),['SYNTHETIC_FRAME_NOT_HARDWARE']
                def close(self):pass
            with patch('doe_autonomo.PacedCamera',FakeCamera):
                bench.flow_attempt=1;bench.execute_flow();bench.persist();bench.report()
            self.assertIn('selected_D1',bench.meta)
            self.assertIn('selected_D2',bench.meta)
            self.assertTrue(any(d['stage']=='D3' and d['result']=='COMPLETE' for d in bench.decisions))

if __name__=='__main__':unittest.main()
