import json
import re
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Image as Figure
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

root = Path(__file__).resolve().parent
output = root / "Informe_integracion_estelar.pdf"
paper = landscape(A4)
styles = getSampleStyleSheet()
styles.add(ParagraphStyle("Kicker", fontName="Helvetica-Bold", fontSize=10, leading=14,
                          textColor=colors.HexColor("#33678A"), spaceAfter=11))
styles.add(ParagraphStyle("TitleDoc", fontName="Helvetica-Bold", fontSize=29, leading=33,
                          textColor=colors.HexColor("#173047"), spaceAfter=15))
styles.add(ParagraphStyle("Prose", parent=styles["Normal"], fontSize=11, leading=15,
                          spaceAfter=9, textColor=colors.HexColor("#203244"), alignment=TA_LEFT))
styles.add(ParagraphStyle("Cell", parent=styles["Prose"], fontSize=9, leading=12, spaceAfter=0))
story = []


def p(value, style="Prose"):
    story.append(Paragraph(escape(value), styles[style]))


def table(rows, widths):
    values = [[Paragraph(escape(str(value)), styles["Cell"]) for value in row] for row in rows]
    grid = Table(values, colWidths=widths, repeatRows=1, hAlign="LEFT")
    grid.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DBE8F2")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#F4F7FA"), colors.white]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
    ]))
    story.extend([grid, Spacer(1, 12)])


def figure(file, max_height=480):
    if not file.exists():
        return
    with Image.open(file) as img:
        width, height = img.size
    factor = min(744 / width, max_height / height)
    story.append(Figure(str(file), width=width * factor, height=height * factor))


def read(path):
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def summary(folder):
    data = read(folder / "timing_ruteado.rpt")
    timing = re.search(r"Design Timing Summary.*?WNS\(ns\).*?\n[ \t-]+\n[ \t]*"
                       r"([\d .+-]+)\n", data, re.S)
    if not timing:
        return None
    return timing[1].split()


def resources(folder):
    data = read(folder / "utilizacion_ruteada.rpt")
    values = []
    for label in ("Slice LUTs", "Slice Registers", "Block RAM Tile", "DSPs"):
        row = re.search(r"^\|\s+" + label + r"\s*\*?\s*\|([^\n]+)", data, re.M)
        if not row:
            values.append("—")
            continue
        columns = [column.strip() for column in row[1].split("|")]
        values.append(f"{columns[0]} / {columns[-3]} ({columns[-2]} %)")
    return values


def render_path_excerpt(folder):
    data = read(folder / "rutas_criticas.rpt")
    start = re.search(r"^Slack \((?:MET|VIOLATED)\)", data, re.M)
    if not start:
        return None
    block = data[start.start():].splitlines()
    excerpt = [block[0]]
    for line in block[1:20]:
        if re.match(r"^\s+(Source|Destination|Path Group|Path Type|Requirement|Data Path Delay|Logic Levels)", line):
            excerpt.append(line.strip())
    font_file = Path("C:/Windows/Fonts/consola.ttf")
    font = ImageFont.truetype(str(font_file), 19) if font_file.exists() else ImageFont.load_default()
    heading = "Vivado 2025.2  |  Extracto de rutas_criticas.rpt"
    lines = [heading, folder.name, ""] + excerpt
    width = max(int(font.getlength(line)) for line in lines) + 64
    image = Image.new("RGB", (max(1024, width), 46 + len(lines) * 31), "#F0F4F8")
    draw = ImageDraw.Draw(image)
    for n, line in enumerate(lines):
        draw.text((32, 24 + n * 31), line, font=font, fill="#20364C")
    filename = folder / "extracto_ruta.png"
    image.save(filename)
    return filename


def render_coverage(data):
    left, top, scale = 114, 98, 10
    shades = ["#E8EDF2", "#DDE7EF", "#CDDFEC", "#AFCADF", "#89B2D0",
              "#558EBA", "#3676A5", "#235981", "#123B5A"]
    grid = data["grilla"]
    width, height = len(grid[0]) * scale, len(grid) * scale
    image = Image.new("RGB", (width + 250, height + 205), "white")
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 24)
    font_small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    heading = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 34)
    draw.text((left, 25), "Estrellas visibles según la orientación", font=heading, fill="#173047")
    for row, values in enumerate(reversed(grid)):
        for col, count in enumerate(values):
            x, y = left + col * scale, top + row * scale
            draw.rectangle((x, y, x + scale - 1, y + scale - 1), fill=shades[count])
    draw.rectangle((left, top, left + width, top + height), outline="#526E84", width=2)
    for tick in range(-40, 41, 10):
        x = left + (tick + 49.5) * scale
        draw.line((x, top + height, x, top + height + 8), fill="#526E84", width=2)
        draw.text((x, top + height + 13), str(tick), anchor="mt", font=font_small, fill="#203244")
    for tick in range(-30, 31, 10):
        y = top + (34.5 - tick) * scale
        draw.line((left - 8, y, left, y), fill="#526E84", width=2)
        draw.text((left - 14, y), str(tick), anchor="rm", font=font_small, fill="#203244")
    draw.text((left + width / 2, top + height + 61), "Giro horizontal (°)",
              anchor="mm", font=font, fill="#203244")
    vertical = Image.new("RGBA", (225, 45), (0, 0, 0, 0))
    ImageDraw.Draw(vertical).text((108, 20), "Inclinación (°)", anchor="mm", font=font, fill="#203244")
    vertical = vertical.rotate(90, expand=True)
    image.paste(vertical, (12, top + (height - vertical.height) // 2), vertical)
    for count, shade in enumerate(shades):
        y = top + 74 + count * 49
        draw.rectangle((left + width + 33, y, left + width + 65, y + 30), fill=shade, outline="#7893A8")
        draw.text((left + width + 77, y + 15), str(count), font=font, anchor="lm", fill="#203244")
    file = root / "cobertura_angular.png"
    image.save(file)
    return file


def page_title(section, title):
    p(section, "Kicker")
    p(title, "TitleDoc")


def footer(canvas, document):
    canvas.setStrokeColor(colors.HexColor("#D5E2EC"))
    canvas.line(46, 36, paper[0] - 46, 36)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#446075"))
    canvas.drawString(46, 22, "Star Tracker · Integración en Vivado")
    canvas.drawRightString(paper[0] - 46, 22, str(document.page))


page_title("TESIS DEFINITIVA · ARTY Z7-10", "Identificación estelar y determinación de actitud")
p("Bitácora de implementación · Vivado 2025.2 · Zynq XC7Z010 · Reloj de proceso de 125 MHz")
final_timing = summary(root / "05_actitud_posruteo")
if final_timing:
    p(f"Resultado ruteado del diseño completo. WNS {final_timing[0]} ns y WHS "
      f"{final_timing[4]} ns, con {final_timing[2]} destinos fallidos en setup y "
      f"{final_timing[6]} en hold.")
p("La lista de centroides de cada cuadro se convierte en rayos unitarios. El identificador "
  "busca correspondencias mediante separaciones angulares entre pares de rayos. La separación "
  "es invariante ante una rotación alrededor del centro óptico.")
p("La ROM guarda 48 direcciones del patrón sintético y 322 parejas de separación menor a 32°. "
  "El controlador usa hasta ocho centroides, en orden de intensidad, y requiere cinco "
  "correspondencias para declarar éxito. Usa el par observado más separado como ancla, "
  "prueba las dos asignaciones posibles y ordena las hipótesis por cantidad y error geométrico.")
p("TRIAD elige una pareja de rayos con el mayor producto cruzado. Construye una base "
  "ortonormal para la observación y otra para el catálogo. La matriz B por la transpuesta de R lleva rayos "
  "de referencia a la cámara. El cuaternión transmitido representa la rotación inversa, "
  "de cámara a referencia, con escala 32768 y w no negativo.")
p("Secuencia UART a 921 600 baudios en el mismo puerto. STY1 entrega la imagen, STC1 los "
  "centroides y STM1 las correspondencias. Cuando se incorpora TRIAD, STQ2 añade el cuaternión.")
p("Se emplea la geometría nominal del patrón G5 a 250 mm y 25° horizontales. La calibración "
  "óptica y la prueba con cámara y FPGA corresponden a una etapa posterior.")

story.append(PageBreak())
page_title("MODELO GEOMÉTRICO Y XSIM", "Cuántas estrellas entran en una toma")
coverage = next(iter(sorted(root.glob("*/sim/cobertura.json"), reverse=True)), None)
if coverage:
    data = json.loads(read(coverage))
    histogram = data["histograma"]
    p(f"Se proyectaron {sum(histogram)} orientaciones con paso de 1° entre −49° y +49° "
      f"en yaw y −34° y +34° en pitch, con roll de 0° y margen de 3 px. En {sum(histogram[:5])} "
      "orientaciones entraron menos de cinco estrellas. En las vistas laterales seleccionadas "
      "entraron seis estrellas con ID fuera de P01–P08.")
    rows = [["Yaw", "Roll", "Pitch", "Visibles", "ID previstos por la geometría"]]
    for scene in data["escenas"]:
        ids = ", ".join(f"P{star:02}" for star in sorted(scene["ids"]))
        rows.append([f"{scene['yaw']}°", f"{scene['roll']}°", f"{scene['pitch']}°", len(scene["ids"]), ids])
    table(rows, [74, 74, 74, 87, 420])
p("Un campo centrado puede contener las ocho referencias nominales. Las vistas laterales "
  "dependen de la densidad del patrón y de la orientación. La cantidad de direcciones de la "
  "ROM y la cantidad de estrellas procesadas en una sola toma son dos parámetros independientes.")
if coverage and "grilla" in data:
    story.append(PageBreak())
    figure(render_coverage(data), 474)

story.append(PageBreak())
page_title("BITÁCORA", "Corridas de síntesis y ruteo")
iterations = json.loads(read(root / "iteraciones.json") or "[]")
rows = [["Versión", "WNS", "TNS", "Fallos setup", "WHS", "THS", "Fallos hold"]]
for iteration in iterations:
    folder = root / iteration["carpeta"]
    values = summary(folder)
    rows.append([iteration["nombre"], *([values[i] for i in (0, 1, 2, 4, 5, 6)] if values else ["—"] * 6)])
table(rows, [255, 75, 75, 85, 75, 75, 85])
for iteration in iterations:
    p(iteration["nombre"] + " · " + iteration["cambio"])
p("WNS y TNS se refieren a setup. WHS y THS se refieren a hold. Los valores de margen están en ns.")
p("Las restricciones existentes dejan 13 entradas y 5 salidas sin retardo de E/S. "
  "El cierre del análisis estático se refiere a las rutas con restricciones. La cámara, "
  "la calibración óptica y el enlace UART físico se comprobarán en el banco.")
p("El reporte CDC del checkpoint final lista seis cruces de un bit sincronizados y un "
  "reset asíncrono sincronizado. Las rutas de setup depuradas pertenecen a clk_fpga_0.")

for iteration in iterations:
    folder = root / iteration["carpeta"]
    story.append(PageBreak())
    page_title("EVIDENCIA DE IMPLEMENTACIÓN", iteration["nombre"])
    p(iteration["evidencia"])
    values = summary(folder)
    if values:
        table([["LUT", "Registros", "Bloques BRAM", "DSP"], resources(folder)], [182] * 4)
        excerpt = render_path_excerpt(folder)
        if excerpt:
            figure(excerpt, 320)
        screenshot = folder / "captura_ruta_vivado.png"
        if not screenshot.exists() and iteration["carpeta"] == "05_actitud_posruteo":
            screenshot = folder / "captura_timing_final.png"
        if screenshot.exists():
            story.append(PageBreak())
            page_title("VISTA DE VIVADO", iteration["nombre"])
            figure(screenshot, 390)
    cases = read(folder / "xsim_identificacion.log") + read(folder / "xsim_actitud.log")
    match = re.findall(r"Note: CASO (\d+) coincidencias (\d+) ciclos (\d+)", cases)
    attitudes = re.findall(r"Note: CASO (\d+) MATCHES (\d+) CICLOS_ID (\d+) CICLOS_Q (\d+) Q ([-\d ]+)", cases)
    if match or attitudes:
        story.append(PageBreak())
        page_title("EVIDENCIA DE SIMULACIÓN", iteration["nombre"])
        if attitudes:
            table([["Caso", "Coincidencias", "Ciclos ID", "Ciclos TRIAD", "w, x, y, z · escala 32768"], *attitudes],
                  [80, 100, 100, 100, 330])
            expected = json.loads(read(folder / "sim" / "cobertura.json"))["escenas"]
            errors = [
                max(abs(a - b) for a, b in zip(map(int, raw.split()), expected[int(index)]["q"]))
                for index, count, _, _, raw in attitudes if int(count) and int(index) < len(expected)
            ]
            p(f"La mayor diferencia entre las componentes simuladas y el cuaternión analítico "
              f"cuantizado fue de {max(errors)} unidades enteras en las vistas probadas.")
        else:
            table([["Caso", "Coincidencias", "Ciclos de identificación"], *match],
                  [120, 150, 230])
    files = iteration.get("diagramas", [])
    for basename in files:
        file = folder / "diagramas" / (basename + ".png")
        if file.exists():
            story.append(PageBreak())
            figure(file, 474)

doc = SimpleDocTemplate(str(output), pagesize=paper, leftMargin=46, rightMargin=46,
                        topMargin=47, bottomMargin=49, title="Integración del Star Tracker",
                        author="Proyecto de tesis")
doc.build(story, onFirstPage=footer, onLaterPages=footer)
