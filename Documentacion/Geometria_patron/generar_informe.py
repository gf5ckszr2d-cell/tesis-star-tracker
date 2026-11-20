"""Informe acotado del modelo pantalla curva y camara. Ejecutar con el runtime PDF."""
import json
import math
from pathlib import Path
from xml.sax.saxutils import escape
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Flowable, KeepTogether
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.colors import HexColor, black, white
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4

HERE=Path(__file__).resolve().parent
D=json.loads((HERE/'resultados_nominales/calculo.json').read_text(encoding='utf-8'))
P=D['parameters']; K=D['camera']; GE=D['geometry']
ROWS={r['id']:r for r in D['stars']}; STAR=ROWS['P21']
ROOT=HERE.parents[1]; OUT=ROOT/'output/pdf/Geometria_patron_estelar.pdf'
OUT.parent.mkdir(parents=True,exist_ok=True)
for name,file in [('Arial','arial.ttf'),('ArialBold','arialbd.ttf'),('ArialItalic','ariali.ttf'),('Mono','consola.ttf')]:
    pdfmetrics.registerFont(TTFont(name,'C:/Windows/Fonts/'+file))
pdfmetrics.registerFontFamily('Arial',normal='Arial',bold='ArialBold',italic='ArialItalic',boldItalic='ArialBold')
SS=getSampleStyleSheet()
SS.add(ParagraphStyle('BodyCustom',fontName='Arial',fontSize=10,leading=14,spaceAfter=8,textColor=black))
SS.add(ParagraphStyle('SmallCustom',fontName='Arial',fontSize=8.5,leading=11.5,spaceAfter=6,textColor=HexColor('#41444a')))
SS.add(ParagraphStyle('TitleCustom',fontName='ArialBold',fontSize=21,leading=25,spaceAfter=14,textColor=black))
SS.add(ParagraphStyle('HeadingCustom',fontName='ArialBold',fontSize=15,leading=19,spaceAfter=10,textColor=black))
SS.add(ParagraphStyle('SubCustom',fontName='ArialBold',fontSize=11,leading=15,spaceBefore=7,spaceAfter=6,textColor=black))
SS.add(ParagraphStyle('EquationCustom',fontName='Mono',fontSize=10,leading=15,spaceAfter=9,leftIndent=12,textColor=black))
SS.add(ParagraphStyle('CellCustom',fontName='Arial',fontSize=8.3,leading=11,textColor=black))
SS.add(ParagraphStyle('CellHeadCustom',fontName='ArialBold',fontSize=8.3,leading=11,textColor=black))
story=[]
def para(text,style='BodyCustom'): story.append(Paragraph(text,SS[style]))
def title(text): para(text,'HeadingCustom')
def sub(text): para(text,'SubCustom')
def eq(text): para(text,'EquationCustom')
def small(text): para(text,'SmallCustom')
def page(): story.append(PageBreak())
def table(rows,widths):
    data=[[Paragraph(escape(str(cell)),SS['CellHeadCustom' if i==0 else 'CellCustom']) for cell in row] for i,row in enumerate(rows)]
    t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
    t.setStyle(TableStyle([('GRID',(0,0),(-1,-1),.5,HexColor('#d9d9d9')),
        ('BACKGROUND',(0,0),(-1,0),HexColor('#e9edf2')),('VALIGN',(0,0),(-1,-1),'MIDDLE'),
        ('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),
        ('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
    story.append(t); story.append(Spacer(1,10))

RED=HexColor('#c33a38'); BLUE=HexColor('#2e64ba'); GOLD=HexColor('#b68916'); GRAY=HexColor('#77818d')
class Figure(Flowable):
    def __init__(self,kind,height): Flowable.__init__(self); self.width=510; self.height=height; self.kind=kind
    def draw(self): getattr(self,self.kind)(self.canv)
    def label(self,c,x,y,text,color=black,size=9): c.setFillColor(color); c.setFont('Arial',size); c.drawString(x,y,text)
    def line(self,c,x1,y1,x2,y2,color=black,width=.8,dash=None):
        c.setStrokeColor(color); c.setLineWidth(width); c.setDash(dash or []); c.line(x1,y1,x2,y2); c.setDash([])
    def arrow(self,c,x1,y1,x2,y2,color=black):
        self.line(c,x1,y1,x2,y2,color); a=math.atan2(y2-y1,x2-x1)
        for da in [-.45,.45]: self.line(c,x2,y2,x2-5*math.cos(a+da),y2-5*math.sin(a+da),color)
    def point(self,c,x,y,r=3,color=black): c.setFillColor(color); c.circle(x,y,r,fill=1,stroke=0)
    def top(self,c):
        ox,oy,scale=255,32,.70
        def pos(x,z): return ox+x*scale,oy+z*scale
        arc=GE['arc_width_mm']; r=P['radius_mm']; d=P['distance_mm']
        path=c.beginPath()
        for i in range(241):
            a=(-.5+i/240)*arc/r; x=r*math.sin(a); z=d-r*(1-math.cos(a)); xx,yy=pos(x,z)
            if i==0: path.moveTo(xx,yy)
            else: path.lineTo(xx,yy)
        c.setLineWidth(2); c.setStrokeColor(RED); c.drawPath(path)
        self.line(c,*pos(0,0),*pos(0,d+7),GRAY,dash=[3,3])
        for b in D['boundary'][:2]: self.line(c,*pos(0,0),*pos(b['Xc_mm'],b['Zc_mm']),BLUE,1.4)
        self.line(c,*pos(0,0),*pos(STAR['Xc_mm'],STAR['Zc_mm']),black,.9,[2,3])
        self.point(c,*pos(0,0)); self.point(c,*pos(STAR['Xc_mm'],STAR['Zc_mm']),4,GOLD)
        self.label(c,ox-24,oy-17,'Cámara C')
        self.label(c,ox+46,oy+39,'FOV H = 25°',BLUE)
        self.label(c,ox+45,oy+178,'P21',GOLD)
        self.label(c,24,oy+125,'Pantalla 1000R',RED)
        self.label(c,331,oy+145,'Xc = 35,773 mm',size=8)
        self.label(c,331,oy+132,'Zc = 249,360 mm',size=8)
        self.line(c,448,oy,448,oy+d*scale,GRAY)
        self.line(c,442,oy,454,oy,GRAY); self.line(c,442,oy+d*scale,454,oy+d*scale,GRAY)
        self.label(c,454,oy+83,'d = 250 mm',size=8)
        self.arrow(c,*pos(-300,d+30),*pos(-240,d+30)); self.label(c,59,oy+(d+42)*scale,'+Xc')
        self.arrow(c,*pos(0,15),*pos(0,75),GRAY); self.label(c,ox-25,oy+45,'+Zc',GRAY)
        self.label(c,125,oy+204,'Ancho recto nominal del modelo = 587,921 mm',size=8)
    def side(self,c):
        ox,oy,sc=54,151,.67; d=P['distance_mm']; h=P['screen_height_mm']; edge=P['distance_mm']-GE['edge_sag_mm']
        def pos(z,y): return ox+z*sc,oy+y*sc
        c.setFillColor(HexColor('#faeeec')); c.setStrokeColor(RED); c.setLineWidth(1)
        c.rect(*pos(edge,-h/2),(d-edge)*sc,h*sc,fill=1,stroke=1)
        self.line(c,*pos(d,-h/2),*pos(d,h/2),RED,2)
        self.line(c,*pos(0,0),*pos(d+10,0),GRAY,.8,[3,3])
        for sign in [-1,1]: self.line(c,*pos(0,0),*pos(d,sign*d*K['tan_v']),BLUE,1.4)
        self.line(c,*pos(0,0),*pos(STAR['Zc_mm'],-STAR['Yc_mm']),black,.9,[2,3])
        self.point(c,*pos(0,0)); self.point(c,*pos(STAR['Zc_mm'],-STAR['Yc_mm']),4,GOLD)
        self.label(c,23,oy-18,'Cámara C'); self.label(c,70,oy+43,'FOV V = 18,881°',BLUE)
        self.label(c,230,oy+16,'P21',GOLD)
        self.line(c,ox,12,ox+d*sc,12,GRAY); self.line(c,ox,8,ox,16,GRAY); self.line(c,ox+d*sc,8,ox+d*sc,16,GRAY)
        self.label(c,98,20,'250 mm hasta el centro de la pantalla',size=8)
        self.arrow(c,296,oy-h*sc/2,296,oy+h*sc/2)
        self.label(c,306,oy,'H = 335,664 mm',size=8)
        self.label(c,306,oy+65,'Rojo claro: proyección lateral',RED,size=8)
        self.label(c,306,oy+52,'de toda la superficie curva.',RED,size=8)
        self.label(c,306,oy+39,'No es el espesor del monitor.',RED,size=8)
        self.arrow(c,335,oy-60,335,oy-23,GRAY); self.label(c,345,oy-34,'+Y del panel',GRAY,size=8)
        self.arrow(c,375,oy-23,375,oy-60,GRAY); self.label(c,387,oy-48,'+Yc',GRAY,size=8)
    def footprint(self,c):
        x0,y0,w,h=20,28,470,264.375
        self.line(c,x0,y0,x0+w,y0,GRAY); self.line(c,x0,y0+h,x0+w,y0+h,GRAY)
        self.line(c,x0,y0,x0,y0+h,GRAY); self.line(c,x0+w,y0,x0+w,y0+h,GRAY)
        def pos(u,v): return x0+(u+.5)/2560*w,y0+(1440-v-.5)/1440*h
        for row in D['stars']:
            x,y=pos(row['u_monitor'],row['v_monitor'])
            self.point(c,x,y,2.6 if row['inside_nominal_fov'] else 1.5,GOLD if row['inside_nominal_fov'] else GRAY)
            if row['inside_nominal_fov']: self.label(c,x+5,y+4,row['id'],size=8)
        path=c.beginPath(); edges=[]
        for i in range(41): edges.append((-1+i/20,-1))
        for i in range(1,41): edges.append((1,-1+i/20))
        for i in range(1,41): edges.append((1-i/20,1))
        for i in range(1,41): edges.append((-1,1-i/20))
        from calcular_geometria import ray_to_screen
        for i,(a,b) in enumerate(edges):
            q=ray_to_screen(a*K['tan_h'],b*K['tan_v'],P); x,y=pos(q['u_monitor'],q['v_monitor'])
            if i==0:path.moveTo(x,y)
            else:path.lineTo(x,y)
        path.close(); c.setStrokeColor(BLUE); c.setLineWidth(1.5); c.drawPath(path)
        # Previous digital crop, kept separate from the optical boundary.
        x,y=pos(903.5,941.5); c.setStrokeColor(GRAY); c.setDash([4,3]); c.rect(x,y,912/2560*w,684/1440*h,fill=0,stroke=1); c.setDash([])
        self.label(c,20,8,'Azul: huella óptica nominal. Discontinuo: recorte digital anterior.',size=8)

para('Geometría del patrón estelar<br/>y proyección sobre la cámara','TitleCustom')
small('Alexander Bolívar Huachaca · Tesis de arquitectura FPGA · 19 de noviembre de 2026')
para('El patrón fijo permite calcular la posición física de cada fuente del monitor y el píxel donde debería aparecer en una cámara alineada. Esta referencia sirve para comprobar el escalado y comparar centroides. El cálculo se limita a la geometría de una pose fija; no estima orientación ni cuaterniones.')
sub('Datos nominales del banco')
table([['Dato','Valor','Procedencia o condición'],
    ['Pantalla activa G5','596,736 × 335,664 mm','Samsung LS27AG550ELXPE [1]'],
    ['Resolución y curvatura','2560 × 1440 px · R = 1000 mm','Ficha del fabricante [1]'],
    ['Distancia al centro','250 mm','Condición de diseño solicitada; centro óptico a pantalla'],
    ['Imagen de cámara','320 × 240 px','Configuración actual de captura consultada; no se modifica'],
    ['FOV horizontal','25° como hipótesis numérica','Valor previo del proyecto; lente exacta por confirmar'],
    ['Patrón de prueba','48 fuentes · semilla 20261119','Referencia fija ya generada; se conserva']], [120,143,247])
story.append(Figure('top',257))
small('Figura 1. Vista superior Xc–Zc según tu esquema. Rojo: pantalla curva; azul: límites horizontales del campo; amarillo: una fuente conocida. La curvatura acerca los extremos a la cámara.')
para('<b>Conclusión nominal:</b> con el patrón actual, una cámara centrada a 250 mm y FOV horizontal supuesto de 25° contiene dos centros, P21 y P28. Los ocho del recorte digital anterior no equivalen a ocho estrellas capturadas. La conclusión depende del FOV real de la lente.')

page(); title('1 Del píxel del monitor a una longitud física')
para('Se usa únicamente la superficie luminosa. El marco, la carcasa y la base no pertenecen al área del patrón. La ficha de Samsung especifica el tamaño activo; no hace falta descontar bordes de esas dimensiones. El patrón debe ocupar el panel completo, sin bandas ni un escalado adicional.')
para('Llamamos (u_m, v_m) a los índices del centro de una estrella: el origen está arriba a la izquierda, u_m crece hacia la derecha y v_m hacia abajo. Los índices empiezan en cero. Para referirlos al borde físico se añade medio píxel.')
eq('p_x = W_arco / 2560 = 0,2331 mm/px<br/>p_y = H / 1440 = 0,2331 mm/px<br/>1 cm = 42,9000 píxeles del monitor')
para('Si eliges como origen la esquina inferior izquierda, la primera estrella P01, en (176, 101), queda a las siguientes distancias sobre la superficie:')
eq('x_izquierda = (176 + 0,5)·0,2331 = 41,14215 mm = 4,11422 cm<br/>y_inferior = (1440 − 101 − 0,5)·0,2331<br/>           = 312,00435 mm = 31,20044 cm')
para('La distancia horizontal anterior sigue el arco del panel. Su proyección recta en X se obtiene con la curvatura. Para un origen en el centro de la pantalla:')
eq('s = (u_m + 0,5 − 1280)·p_x<br/>Y_panel = (720 − v_m − 0,5)·p_y')
sub('Qué significa el ancho de una pantalla curva')
para('En el ejemplo se interpreta W = 596,736 mm como longitud de arco, igual que en el modelo previo del generador. La ficha publica el tamaño activo, pero no declara aquí si su ancho es arco o cuerda; esa interpretación queda identificada como hipótesis. Si el ancho disponible es una medida recta entre extremos, se convierte primero:')
eq('W_arco = 2R·asin(W_cuerda / 2R)<br/>W_cuerda = 2R·sin(W_arco / 2R)')
para('Con el convenio de arco usado, la cuerda es 587,921 mm y los extremos se adelantan 44,182 mm respecto al centro. Si 596,736 mm fuese la cuerda, habría que recalcular con el arco correspondiente. No se deben mezclar ambas medidas.')
small('La precisión de los decimales refleja el cálculo nominal, no una medición del montaje. Si se utiliza una región del monitor o quedan márgenes digitales, hay que guardar su desplazamiento y su escala antes de aplicar estas ecuaciones.')

page(); title('2 De la pantalla curva a las coordenadas XYZ')
para('La cámara se sitúa frente al centro, a la misma altura y con su eje perpendicular al plano tangente central. Se representa el panel como un cilindro vertical de radio R. La pantalla curva tiene profundidad variable, aunque no tenga curvatura vertical.')
eq('α = s / R<br/>Xc = R·sin(α)<br/>δ = R·[1 − cos(α)]<br/>Yc = −Y_panel<br/>Zc = d − δ')
para('En el sistema de cámara se usa <b>Xc hacia la derecha, Yc hacia abajo y Zc hacia la pantalla</b>. Así coincide el signo vertical con los píxeles de imagen [2]. La altura del panel sigue siendo positiva hacia arriba: Y_panel = −Yc. En el centro Zc = 250 mm; para una estrella fuera del centro, Zc cambia con δ.')
story.append(Figure('side',290))
small('Figura 2. Vista lateral Zc–Y. La banda roja representa la proyección de la pantalla curva completa al mirar desde un costado. La sección vertical central es recta; la banda no representa material macizo. El FOV vertical es menor que el horizontal en el modelo de imagen 4:3.')
para('La longitud del rayo hasta la estrella tampoco es igual a Zc. Su distancia es ρ = √(Xc² + Yc² + Zc²). Para comparar direcciones, la referencia puede expresarse como r_ref = (Xc, Yc, Zc)/ρ. Esto no convierte a la cámara en un sensor de profundidad.')

page(); title('3 Proyección a píxeles y ejemplo manual')
para('El paso del monitor convierte píxeles de pantalla a milímetros. La proyección de cámara utiliza después la relación lateral/profundidad. Una sola división entre las resoluciones de ambas imágenes no incluye esta perspectiva.')
eq('f_x = N_x / [2·tan(FOV_H/2)]<br/>FOV_V = 2·atan[(N_y/N_x)·tan(FOV_H/2)]<br/>u_ref = c_x + f_x·Xc/Zc<br/>v_ref = c_y + f_y·Yc/Zc')
para('Se aplica el modelo de cámara ideal [2], con píxeles cuadrados, f_y = f_x y distorsión nula supuesta. Para 320 × 240 y FOV_H = 25°, f_x = f_y = 721,713 px y FOV_V = 18,8805°. El punto principal nominal es (159,5; 119,5), centro de los índices de píxel. Debe usarse el mismo convenio al comparar con los centroides; (160; 120) supone un desplazamiento de medio píxel.')
sub('Ejemplo de la estrella P21')
eq('Monitor: (u_m, v_m) = (1433, 636)<br/>s = (1433 + 0,5 − 1280)·0,2331 = 35,78085 mm<br/>Y_panel = (720 − 636 − 0,5)·0,2331 = 19,46385 mm<br/>α = 35,78085/1000 = 0,03578085 rad<br/>Xc = 1000·sin(α) = 35,77322 mm<br/>δ = 1000·[1 − cos(α)] = 0,64007 mm<br/>Yc = −19,46385 mm; Zc = 250 − δ = 249,35993 mm<br/>u_ref = 159,5 + 721,71336·35,77322/249,35993<br/>      = 263,03711 px<br/>v_ref = 119,5 − 721,71336·19,46385/249,35993<br/>      = 63,16649 px')
para('P21 debería aparecer cerca de <b>(263,04; 63,17)</b> en esta captura nominal. Su dirección unitaria es aproximadamente (0,141584; −0,077035; 0,986924), y la distancia por el rayo es 252,664 mm. Son coordenadas de referencia calculadas, no centroides medidos.')
sub('La escala es local')
para('Cerca del centro, la escala aproximada es f_x·p_x/d = 0,67293 píxeles de cámara por píxel del monitor. Fuera del centro cambia por la curvatura y por Zc. Si la misma escena se remuestrea a 160 × 120 sin recorte óptico, las focales se reducen a la mitad y se conserva el FOV; no se cambia ningún RTL para este informe.')

page(); title('4 Cuántas estrellas entran en la imagen')
para('En el plano central, la huella aproximada es 2d·tan(FOV_H/2) por 2d·tan(FOV_V/2): <b>110,847 × 83,135 mm</b>. Al intersectar los rayos con el cilindro, el ancho real en X es 110,174 mm, equivalente a 110,230 mm de arco. Los bordes superior e inferior también dependen de la profundidad local.')
story.append(Figure('footprint',303))
small('Figura 3. El mismo patrón de 48 fuentes. La huella óptica nominal azul es menor que el recorte digital de ocho centros. No se ha desplazado ni regenerado ninguna estrella.')
table([['Centro del recorte previo','u_ref en cámara','v_ref en cámara','Dentro del FOV nominal']]+[[i,f"{ROWS[i]['u_expected']:.2f}",f"{ROWS[i]['v_expected']:.2f}",'Sí' if ROWS[i]['inside_nominal_fov'] else 'No'] for i in ['P12','P13','P20','P21','P22','P28','P29','P30']],[155,100,100,155])
para('Para conservar 250 mm y obtener ocho fuentes, primero debe confirmarse el FOV de la lente; después se eligen o ubican ocho fuentes dentro de la huella, con margen para su tamaño. Como ilustración matemática, con este patrón centrado se incluyen ocho centros al usar aproximadamente 48,45° horizontales, o al situar la cámara a 501,63 mm manteniendo 25°. No son valores medidos ni una propuesta de cambiar ahora el montaje. Contar centros no garantiza fuentes completas ni detectadas.')

page(); title('5 Comparación con los centroides y la memoria')
para('Para esta comprobación basta con asociar manualmente los identificadores conocidos de una toma fija. Cada registro de referencia conserva ID, posición del monitor, XYZ en milímetros y píxel esperado. La tabla completa se entrega para las 48 fuentes; la selección nominal a 25 cm y 25° contiene P21 y P28.')
table([['ID','Xc mm','Yc mm','Zc mm','u_ref px','v_ref px']]+[[i]+[f"{ROWS[i][key]:.4f}" for key in ['Xc_mm','Yc_mm','Zc_mm','u_expected','v_expected']] for i in D['visible_ids']],[40,94,94,94,94,94])
para('La memoria de la FPGA puede guardar las coordenadas esperadas ya proyectadas. El cálculo trigonométrico se hace en la PC y el comparador recibe la referencia en las mismas unidades que los centroides. Conservar XYZ en los datos de preparación permite auditar cómo se obtuvo cada píxel esperado. <b>Los milímetros de la memoria no se comparan directamente con píxeles de captura.</b>')
eq('Δu_i = u_centroide,i − u_ref,i<br/>Δv_i = v_centroide,i − v_ref,i<br/>e_i = √(Δu_i² + Δv_i²)')
para('Se comparan todos los centros esperados visibles y se anotan fuentes extra, ausentes o recortadas. Se reportan error medio, máximo y repetibilidad de varias tomas. El criterio de aceptación en píxeles se fija antes de validar y debe considerar incertidumbre geométrica, calibración, foco y umbral; aquí no se inventa una tolerancia aprobada.')
sub('Si se desea comprobar de nuevo XYZ')
para('El centroide define un rayo con a = (u − c_x)/f_x y b = (v − c_y)/f_y, tras corregir distorsión cuando esté calibrada. Al imponer que la fuente pertenece a este cilindro conocido y a esta pose fija:')
eq('X = aZ; Y = bZ<br/>X² + [Z − (d − R)]² = R²<br/>Z = {d − R + √[R²(1+a²) − a²(d−R)²]}/(1+a²)')
para('Se toma la intersección frontal dentro del área activa. La reconstrucción depende de la pantalla y de la pose asumidas; no demuestra que la cámara haya medido profundidad. Una transformación de ida y vuelta verifica las cuentas, pero la captura real es la comprobación independiente del modelo.')
small('Formato numérico futuro: si se guardan coordenadas multiplicadas por 256, X de 320 píxeles exige al menos 17 bits sin signo. Un campo de 16 bits con ocho bits fraccionarios llega solo hasta 255,996 px. P21 vale 67338 en esa escala. Los CSV incluyen enteros escalados; no se ha generado ni cargado una ROM, ni modificado RTL.')

page(); title('6 Datos de fabricante y comprobación experimental')
sub('Qué queda sustentado por la documentación')
para('Samsung publica el tamaño activo, la resolución y la curvatura del modelo usado [1]. Los 250 mm son la condición elegida del banco. El FOV pertenece al conjunto sensor y lente: “OV7670” por sí solo no identifica la óptica instalada.')
para('La guía OV7670 conservada en el repositorio no permitió establecer el FOV de esa lente. Además, la hoja de OmniVision del módulo OV7670MFSL distingue <i>Chief Ray Angle</i> de 25° en su primera página y ángulo de visión diagonal de 58° en su tabla óptica, página 9 [3]. Por ello, no se presenta 25° como FOV horizontal certificado de tu cámara. Se conserva como hipótesis del ejemplo existente hasta identificar la ficha exacta del módulo y la dirección del ángulo publicado.')
eq('Si el manual da FOV diagonal θ_D para una imagen 4:3:<br/>FOV_H = 2·atan[(4/5)·tan(θ_D/2)]<br/>FOV_V = 2·atan[(3/5)·tan(θ_D/2)]')
small('Estas conversiones suponen proyección ideal, píxeles cuadrados y ausencia de recorte adicional. No se sustituye el FOV por el ángulo de visión de 178° del monitor.')
sub('Comprobación sobre el banco')
for number,text in enumerate([
    'Mostrar el patrón fijo a resolución nativa y conservar su ID. Registrar posición de cámara, distancia al centro óptico, enfoque y modo de captura. Mantener la cámara alineada y el panel sin inclinación respecto a la pose de referencia.',
    'Confirmar qué manual y lente corresponden al módulo, y si el FOV indicado es horizontal, vertical o diagonal. Usar ese dato nominal para actualizar los parámetros del cálculo.',
    'Capturar la imagen y los centroides de la misma toma. Comprobar que un movimiento a la derecha aumenta u y que una fuente arriba reduce v; resolver cualquier inversión antes de comparar.',
    'Superponer cada punto esperado con el centroide observado y calcular los residuos. Una desviación común sugiere desplazamiento del centro principal; una variación con la posición puede indicar error de escala, alineación o distorsión. Son diagnósticos que deben comprobarse.',
    'Cuando se pase de geometría nominal a validación, ajustar los parámetros con puntos de calibración y evaluar con otras posiciones o tomas independientes. Una coincidencia obtenida usando los mismos puntos para ajustar y evaluar no es una validación independiente.'
],1): para(f'<b>{number}.</b> {text}')
sub('Archivos y trazabilidad')
small('calcular_geometria.py reproduce las 48 transformaciones y sus pruebas de consistencia. resultados_nominales/calculo.json conserva parámetros y resultados; referencia_48.csv contiene XYZ y píxeles esperados; ocho_del_recorte_digital.csv comprueba el recorte previo. La tabla ocho_solo_distancia_alternativa.csv corresponde exclusivamente al escenario de 501,63 mm, no al banco de 250 mm. Todos son resultados nominales calculados. La carga de memoria y la validación física quedan pendientes.')
sub('Referencias')
small('[1] Samsung Perú. Especificaciones LS27AG550ELXPE. <link href="https://www.samsung.com/pe/monitors/gaming/odyssey-g5-g55a-27-inch-165hz-1ms-ls27ag550elxpe/" color="#2e64ba">Ficha del monitor</link>. Consulta: 19/11/2026.')
small('[2] OpenCV. Camera Calibration and 3D Reconstruction. Modelo de cámara e intrínsecos. <link href="https://docs.opencv.org/4.x/d9/d0c/group__calib3d.html" color="#2e64ba">Documentación oficial</link>.')
small('[3] OmniVision. OV7670MFSL Camera Module, versión 1.31, pp. 1 y 9. <link href="https://w2.electrodragon.com/Chip-dat/OmniVision-dat/OV7670-dat/OV7670-ds.pdf" color="#2e64ba">Hoja del fabricante en distribución de Electrodragon</link>. Se consulta para distinguir los ángulos; no identifica el módulo físico del banco.')

def footer(c,doc):
    c.setFont('Arial',8); c.setFillColor(GRAY)
    c.drawString(42,22,'Geometría del patrón estelar · Cálculo nominal · Sin estimación de actitud')
    c.drawRightString(A4[0]-42,22,str(doc.page))
doc=SimpleDocTemplate(str(OUT),pagesize=A4,leftMargin=42,rightMargin=42,topMargin=36,bottomMargin=38,
    title='Geometría del patrón estelar y proyección sobre la cámara',author='Alexander Bolívar Huachaca')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(OUT)
