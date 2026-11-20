"""Sensibilidad geometrica de la ROM fija; simulacion PC, no calibracion ni matching."""
import csv
import math
import sys
from generar_rom import referencias

def transformar(x,y,z,yaw=0,pitch=0,roll=0):
    """Pc=Rz(-roll)*Rx(-pitch)*Ry(-yaw)*P. Angulos de camara en grados."""
    a,b,c=map(math.radians,(yaw,pitch,roll))
    x1,y1,z1=math.cos(a)*x-math.sin(a)*z,y,math.sin(a)*x+math.cos(a)*z
    x2,y2,z2=x1,math.cos(b)*y1+math.sin(b)*z1,-math.sin(b)*y1+math.cos(b)*z1
    return math.cos(c)*x2+math.sin(c)*y2,-math.sin(c)*x2+math.cos(c)*y2,z2

def proyectar(fila,datos,distancia,yaw=0,pitch=0,roll=0):
    p,k=datos['parameters'],datos['camera']
    x,y,z=transformar(fila['Xc_mm'],fila['Yc_mm'],fila['Zc_mm']+distancia-p['distance_mm'],yaw,pitch,roll)
    if z <= 0: return None
    u,v=k['cx']+k['fx']*x/z,k['cy']+k['fy']*y/z
    return u,p['image_height_px']-1-v,(-.5 <= u < p['image_width_px']-.5 and -.5 <= v < p['image_height_px']-.5)

def main():
    datos,refs=referencias(); p=datos['parameters']
    filas={int(f['id'][1:]):f for f in datos['stars']}
    casos=[('nominal',p['distance_mm'],0,0,0),('distancia_24cm',240,0,0,0)]
    for eje in ['yaw','pitch','roll']:
        for ang in [-2,-1,1,2]:
            giros={'yaw':0,'pitch':0,'roll':0}; giros[eje]=ang
            casos.append((f'{eje}_{ang:+d}',p['distance_mm'],giros['yaw'],giros['pitch'],giros['roll']))
    casos.append(('24cm_yaw2_pitch2_roll2',240,2,2,2))
    columnas=['caso','id','distancia_mm','yaw_deg','pitch_deg','roll_deg','x_px','y_px',
              'dx_contra_rom_px','dy_contra_rom_px','error_contra_rom_px','error_geometrico_px',
              'visible_actual','centros_actuales_en_fov']
    w=csv.DictWriter(sys.stdout,fieldnames=columnas,lineterminator='\n'); w.writeheader()
    for caso,d,yaw,pitch,roll in casos:
        cantidad=sum(bool(proyectar(f,datos,d,yaw,pitch,roll)[2]) for f in datos['stars'])
        for ref in refs:
            x,y,visible=proyectar(filas[ref['id']],datos,d,yaw,pitch,roll)
            dx,dy=x-ref['x_256']/256,y-ref['y_256']/256
            w.writerow(dict(zip(columnas,[caso,ref['nombre'],d,yaw,pitch,roll,x,y,dx,dy,
                math.hypot(dx,dy),math.hypot(x-ref['x_px'],y-ref['y_px']),int(visible),cantidad])))

if __name__ == '__main__': main()
