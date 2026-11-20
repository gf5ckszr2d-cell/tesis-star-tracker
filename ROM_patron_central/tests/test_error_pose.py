import contextlib
import csv
import io
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import evaluar_error_pose as pose
from generar_rom import referencias

class ErrorPose(unittest.TestCase):
    def setUp(self):
        self.datos,self.refs=referencias()
        self.k=self.datos['camera']
        self.centro=dict(Xc_mm=0,Yc_mm=0,Zc_mm=250)

    def test_referencia_fija(self):
        self.assertEqual([(r['id'],r['x_256'],r['y_256']) for r in self.refs],
                         [(21,67338,45013),(28,27128,16370)])

    def test_yaw_en_eje_optico(self):
        x,y,_=pose.proyectar(self.centro,self.datos,250,yaw=1)
        self.assertAlmostEqual(x,159.5-self.k['fx']*math.tan(math.radians(1)))
        self.assertAlmostEqual(y,119.5)

    def test_pitch_en_eje_optico(self):
        x,y,_=pose.proyectar(self.centro,self.datos,250,pitch=2)
        self.assertAlmostEqual(x,159.5)
        self.assertAlmostEqual(y,119.5-self.k['fy']*math.tan(math.radians(2)))

    def test_rotacion_conserva_distancia(self):
        a=(35.7,-19.4,249.3); b=pose.transformar(*a,yaw=2,pitch=-1,roll=2)
        self.assertAlmostEqual(sum(x*x for x in a),sum(x*x for x in b),places=8)

    def test_distancia_24cm(self):
        fila=next(r for r in self.datos['stars'] if r['id']=='P21')
        x,y,_=pose.proyectar(fila,self.datos,240)
        self.assertAlmostEqual(x,159.5+self.k['fx']*fila['Xc_mm']/(fila['Zc_mm']-10))
        self.assertGreater(x,self.refs[0]['x_px'])
        self.assertGreater(y,self.refs[0]['y_px'])

    def test_barrido_no_modifica_rom(self):
        path=Path(__file__).resolve().parents[1]/'rtl/patron_central_pkg.vhd'
        antes=path.read_bytes(); salida=io.StringIO()
        with contextlib.redirect_stdout(salida): pose.main()
        filas=list(csv.DictReader(io.StringIO(salida.getvalue())))
        self.assertEqual(len(filas),30)
        self.assertEqual(path.read_bytes(),antes)
        for r in filas:
            if r['caso']=='nominal':
                self.assertAlmostEqual(float(r['error_geometrico_px']),0)
                self.assertLessEqual(float(r['error_contra_rom_px']),math.sqrt(2)/512)

if __name__=='__main__': unittest.main()
