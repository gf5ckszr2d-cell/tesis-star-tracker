"""Offline characterization of ONE isolated star in original grayscale PNGs.
No operational FPGA processing is replaced. Requires Pillow only.
"""
import argparse
import csv
import json
import math
from pathlib import Path
import statistics as st
from PIL import Image, ImageFilter


def crossing(profile, peak, level, direction):
    i = peak
    while 0 <= i+direction < len(profile):
        j = i+direction
        if profile[j] <= level < profile[i]:
            return i+(j-i)*(level-profile[i])/(profile[j]-profile[i])
        i = j
    return None


def measure(image, center=None, radius=6, threshold=45):
    image = image.convert('L')
    w,h = image.size
    if center is None:
        smooth = image.filter(ImageFilter.BoxBlur(1))
        values = list(smooth.tobytes())
        seed = max(range(len(values)), key=values.__getitem__)
        center = (seed%w,seed//w)
    cx,cy = center
    if not (0<=cx<w and 0<=cy<h):
        raise ValueError('ROI center outside image')
    x0,y0 = max(0,cx-radius), max(0,cy-radius)
    x1,y1 = min(w,cx+radius+1), min(h,cy+radius+1)
    roi = image.crop((x0,y0,x1,y1)); rw,rh = roi.size
    if min(rw,rh)<3:
        raise ValueError('ROI too small')
    data = list(roi.tobytes())
    border = [data[y*rw+x] for y in range(rh) for x in range(rw)
              if x in (0,rw-1) or y in (0,rh-1)]
    bg = st.median(border)
    noise = st.pstdev(border)
    mad = 1.4826*st.median(abs(v-bg) for v in border)
    peak_index = max(range(len(data)), key=data.__getitem__)
    px,py = peak_index%rw,peak_index//rw
    peak = data[peak_index]
    half = bg+(peak-bg)/2
    horizontal = [data[py*rw+x] for x in range(rw)]
    vertical = [data[y*rw+px] for y in range(rh)]
    left,right = crossing(horizontal,px,half,-1),crossing(horizontal,px,half,1)
    top,bottom = crossing(vertical,py,half,-1),crossing(vertical,py,half,1)
    # Connected component containing the peak, using the RTL absolute threshold.
    component = set()
    todo = [(px,py)] if peak>=threshold else []
    while todo:
        p=todo.pop()
        if p in component:
            continue
        x,y=p
        if not (0<=x<rw and 0<=y<rh) or data[y*rw+x]<threshold:
            continue
        component.add(p)
        todo.extend((x+dx,y+dy) for dx in (-1,0,1) for dy in (-1,0,1) if dx or dy)
    total = sum(data[y*rw+x] for x,y in component)
    gx = sum((x+x0)*data[y*rw+x] for x,y in component)/total if total else None
    gy = sum((y+y0)*data[y*rw+x] for x,y in component)/total if total else None
    flags=[]
    if x0==0 or y0==0 or x1==w or y1==h:
        flags.append('ROI_AT_IMAGE_EDGE')
    if any(x in (0,rw-1) or y in (0,rh-1) for x,y in component):
        flags.append('COMPONENT_TOUCHES_ROI')
    if any(v==255 for v in data):
        flags.append('SATURATED')
    if len(component)<2:
        flags.append('AREA_BELOW_RTL_MIN_2')
    if right is None or left is None or bottom is None or top is None:
        flags.append('FWHM_NOT_CLOSED')
    if peak-bg < max(5*noise,5):
        flags.append('LOW_PEAK_CONTRAST')
    return dict(width=w,height=h,peak=peak,background=bg,noise_std=noise,noise_mad=mad,
                peak_contrast_snr=(peak-bg)/noise if noise else None,
                saturated_pixels=sum(v==255 for v in data),
                near_rail_pixels=sum(v>=250 for v in data),threshold=threshold,
                component_area=len(component),centroid_x=gx,centroid_y=gy,
                fwhm_x=right-left if right is not None and left is not None else None,
                fwhm_y=bottom-top if bottom is not None and top is not None else None,
                flags=';'.join(flags))


def main():
    p=argparse.ArgumentParser(description='Mide una estrella aislada: FWHM y centroide 8-conectado ponderado con Y')
    p.add_argument('images',nargs='+',type=Path)
    p.add_argument('--center',nargs=2,type=int,metavar=('X','Y'))
    p.add_argument('--radius',type=int,default=6)
    p.add_argument('--threshold',type=int,default=45)
    p.add_argument('--output',type=Path,default=Path(__file__).resolve().parent/'calibracion')
    a=p.parse_args()
    if a.radius<2 or not 0<=a.threshold<=255:
        p.error('radius >=2 y threshold entre 0 y 255')
    rows=[]
    for path in a.images:
        with Image.open(path) as image:
            rows.append(dict(file=str(path.resolve()),**measure(image,a.center,a.radius,a.threshold)))
    if len({(r['width'],r['height']) for r in rows})!=1:
        p.error('No mezclar resoluciones en una serie de repetibilidad')
    a.output.mkdir(parents=True,exist_ok=True)
    with (a.output/'estrellas.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
    valid=[r for r in rows if not r['flags'] and r['centroid_x'] is not None]
    summary={'images':len(rows),'unflagged_images':len(valid),
             'method':'FWHM of peak-row/column by linear interpolation; not a PSF fit',
             'centroid':'8-connected component at absolute threshold, intensity Y weights; offline only',
             'exposure_ms':None,'angular_speed_deg_s':None,
             'warning':'Jitter includes scene/camera drift; does not establish centroid accuracy or bias.'}
    if len(valid)>1:
        summary.update(centroid_std_x_px=st.pstdev(r['centroid_x'] for r in valid),
                       centroid_std_y_px=st.pstdev(r['centroid_y'] for r in valid))
    (a.output/'resumen.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary,indent=2))
    for row in rows:
        print(Path(row['file']).name,'FWHM=',row['fwhm_x'],row['fwhm_y'],'flags=',row['flags'] or 'ninguna')


if __name__=='__main__':
    main()
