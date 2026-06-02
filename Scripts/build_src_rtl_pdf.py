from __future__ import annotations

import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    PageBreak,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / "Docs" / "EXPLICACION_SRC_RTL.md"
OUT = REPO_ROOT / "Docs" / "EXPLICACION_SRC_RTL.pdf"


def _escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def _inline(text: str) -> str:
    text = _escape(text)
    text = re.sub(r"`([^`]+)`", r"<font name='Courier'>\1</font>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    return text


def _split_table_row(line: str) -> list[str]:
    row = line.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|"):
        row = row[:-1]
    return [cell.strip() for cell in row.split("|")]


def _is_separator(line: str) -> bool:
    cells = _split_table_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c) for c in cells)


def _page_number(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawRightString(A4[0] - 1.6 * cm, 1.0 * cm, f"Página {doc.page}")
    canvas.restoreState()


def build_pdf() -> None:
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="TitlePage",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=24,
            leading=30,
            alignment=TA_CENTER,
            spaceAfter=24,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H1Custom",
            parent=styles["Heading1"],
            fontSize=17,
            leading=21,
            spaceBefore=14,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H2Custom",
            parent=styles["Heading2"],
            fontSize=13,
            leading=16,
            spaceBefore=10,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodyCustom",
            parent=styles["BodyText"],
            fontSize=9.2,
            leading=12.2,
            spaceAfter=5,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BulletCustom",
            parent=styles["BodyText"],
            leftIndent=12,
            firstLineIndent=-8,
            fontSize=9.2,
            leading=12.2,
            spaceAfter=3,
        )
    )
    code_style = ParagraphStyle(
        name="Code",
        fontName="Courier",
        fontSize=7.2,
        leading=8.6,
        textColor=colors.HexColor("#111111"),
        backColor=colors.HexColor("#F4F4F4"),
        borderColor=colors.HexColor("#DDDDDD"),
        borderWidth=0.4,
        borderPadding=5,
        spaceBefore=4,
        spaceAfter=7,
    )

    doc = BaseDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=1.45 * cm,
        rightMargin=1.45 * cm,
        topMargin=1.35 * cm,
        bottomMargin=1.35 * cm,
        title="Explicación RTL del sistema star_tracker_top",
        author="Codex",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")
    doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=_page_number)])

    lines = SRC.read_text(encoding="utf-8").splitlines()
    story = []
    i = 0
    first_h1 = True

    while i < len(lines):
        line = lines[i]

        if not line.strip():
            i += 1
            continue

        if line.startswith("```"):
            block: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                block.append(lines[i])
                i += 1
            if i < len(lines):
                i += 1
            story.append(Preformatted("\n".join(block), code_style, maxLineLength=105))
            continue

        if line.startswith("|") and i + 1 < len(lines) and _is_separator(lines[i + 1]):
            header = _split_table_row(line)
            i += 2
            rows = [header]
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(_split_table_row(lines[i]))
                i += 1

            col_count = max(len(r) for r in rows)
            normalized = []
            for row in rows:
                row = row + [""] * (col_count - len(row))
                normalized.append([Paragraph(_inline(cell), styles["BodyCustom"]) for cell in row])

            table = Table(normalized, repeatRows=1)
            table.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#EAEAEA")),
                        ("TEXTCOLOR", (0, 0), (-1, 0), colors.black),
                        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#BDBDBD")),
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                        ("LEFTPADDING", (0, 0), (-1, -1), 4),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                        ("TOPPADDING", (0, 0), (-1, -1), 3),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                    ]
                )
            )
            story.append(table)
            story.append(Spacer(1, 6))
            continue

        if line.startswith("# "):
            title = line[2:].strip()
            story.append(Spacer(1, 6 * cm))
            story.append(Paragraph(_inline(title), styles["TitlePage"]))
            story.append(Paragraph("Documentación generada desde Docs/EXPLICACION_SRC_RTL.md", styles["BodyCustom"]))
            story.append(PageBreak())
            first_h1 = False
            i += 1
            continue

        if line.startswith("## "):
            if not first_h1 and line.startswith("## 2. "):
                story.append(PageBreak())
            story.append(Paragraph(_inline(line[3:].strip()), styles["H1Custom"]))
            i += 1
            continue

        if line.startswith("### "):
            story.append(Paragraph(_inline(line[4:].strip()), styles["H2Custom"]))
            i += 1
            continue

        if re.match(r"^\d+\. ", line.strip()):
            story.append(Paragraph(_inline(line.strip()), styles["BodyCustom"]))
            i += 1
            continue

        if line.startswith("- "):
            story.append(Paragraph("• " + _inline(line[2:].strip()), styles["BulletCustom"]))
            i += 1
            continue

        story.append(Paragraph(_inline(line.strip()), styles["BodyCustom"]))
        i += 1

    doc.build(story)


if __name__ == "__main__":
    build_pdf()
    print(f"PDF generado: {OUT}")
