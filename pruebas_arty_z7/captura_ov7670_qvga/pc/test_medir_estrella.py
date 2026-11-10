import math
import unittest
from PIL import Image
from medir_estrella import measure


class StarMeasurementTest(unittest.TestCase):
    def test_isolated_gaussian_and_width(self):
        image=Image.new('L',(31,31))
        for y in range(31):
            for x in range(31):
                image.putpixel((x,y),round(10+180*math.exp(-((x-15)**2+(y-15)**2)/2)))
        r=measure(image,(15,15),6,45)
        self.assertAlmostEqual(r['centroid_x'],15)
        self.assertAlmostEqual(r['centroid_y'],15)
        self.assertAlmostEqual(r['fwhm_x'],2.355,delta=.15)
        self.assertFalse(r['flags'])
    def test_saturation_and_tiny_component_are_flagged(self):
        image=Image.new('L',(31,31),10); image.putpixel((15,15),255)
        r=measure(image,(15,15),6,45)
        self.assertIn('SATURATED',r['flags'])
        self.assertIn('AREA_BELOW_RTL_MIN_2',r['flags'])
    def test_no_star_is_not_reported_as_good(self):
        r=measure(Image.new('L',(31,31),10),(15,15),6,45)
        self.assertIsNone(r['centroid_x'])
        self.assertIn('LOW_PEAK_CONTRAST',r['flags'])


if __name__=='__main__': unittest.main()
