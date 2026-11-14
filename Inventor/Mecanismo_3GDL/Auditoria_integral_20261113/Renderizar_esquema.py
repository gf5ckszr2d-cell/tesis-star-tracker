"""Rasteriza el esquema vectorial nuevo; no lee ni edita capturas del usuario."""
from pathlib import Path
import math
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent
svg = ET.parse(root / "Centro_mecanico_y_punto_del_barril.svg").getroot()
scale = 1.5
image = Image.new("RGB", (1650,705), "white")
draw = ImageDraw.Draw(image)
font_path = "C:/Windows/Fonts/arial.ttf"
def n(e,k,default=0): return float(e.get(k,default))*scale
for e in svg.iter():
    tag=e.tag.split("}")[-1]
    stroke=e.get("stroke", "#162434")
    width=max(1,round(n(e,"stroke-width",1)))
    if tag=="rect":
        draw.rectangle((n(e,"x"),n(e,"y"),n(e,"x")+n(e,"width"),n(e,"y")+n(e,"height")),fill=e.get("fill","white"))
    elif tag=="line":
        a=(n(e,"x1"),n(e,"y1"));b=(n(e,"x2"),n(e,"y2"))
        if e.get("stroke-dasharray"):
            length=math.dist(a,b)
            for start in range(0,round(length),15):
                lo=start/length;hi=min(start+7.5,length)/length
                draw.line(tuple((a[k]+t*(b[k]-a[k])) for t in (lo,hi) for k in (0,1)),fill=stroke,width=width)
        else: draw.line((*a,*b),fill=stroke,width=width)
    elif tag=="polyline":
        points=[tuple(float(v)*scale for v in pair.split(",")) for pair in e.get("points").split()]
        draw.line(points,fill=stroke,width=width,joint="curve")
    elif tag=="circle":
        x,y,r=n(e,"cx"),n(e,"cy"),n(e,"r")
        draw.ellipse((x-r,y-r,x+r,y+r),fill=e.get("fill","#162434"))
    elif tag=="text":
        font=ImageFont.truetype(font_path,round(n(e,"font-size",15)))
        draw.text((n(e,"x"),n(e,"y")),e.text or "",font=font,fill=e.get("fill","#162434"),anchor="ls")
image.save(root / "Centro_mecanico_y_punto_del_barril.png")
