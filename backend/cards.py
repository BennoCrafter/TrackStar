"""Renders printable, duplex-ready card sheets: QR code fronts and song info backs."""

import unicodedata
from pathlib import Path

from reportlab.graphics import renderPDF
from reportlab.graphics.barcode.qr import QrCodeWidget
from reportlab.graphics.shapes import Drawing
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.utils import simpleSplit
from reportlab.pdfgen.canvas import Canvas
from songs import Song

PAGE_W, PAGE_H = A4
CARD = 6.5 * cm
COLS, ROWS = 3, 4
MARGIN_X = (PAGE_W - COLS * CARD) / 2
MARGIN_Y = (PAGE_H - ROWS * CARD) / 2
PAD = 0.5 * cm

INK = HexColor("#1F1B2E")
MUTED = HexColor("#8A8799")
GUIDE = HexColor("#D9D7E0")

# back side gradient per 5-year period, dark enough for white text;
PERIOD_COLORS = {
    None: ("#334155", "#64748B"),  # no year: neutral slate
    1950: ("#3B0764", "#7E22CE"),
    1955: ("#1E3A8A", "#4338CA"),
    1960: ("#9F1239", "#EA580C"),
    1965: ("#0E7490", "#0D9488"),
    1970: ("#9A3412", "#CA8A04"),
    1975: ("#4D7C0F", "#15803D"),
    1980: ("#BE185D", "#6D28D9"),
    1985: ("#0369A1", "#7C3AED"),
    1990: ("#0F766E", "#0369A1"),
    1995: ("#A21CAF", "#DB2777"),
    2000: ("#1E40AF", "#7C3AED"),
    2005: ("#B45309", "#DC2626"),
    2010: ("#065F46", "#4D7C0F"),
    2015: ("#4338CA", "#0891B2"),
    2020: ("#B91C1C", "#C026D3"),
    2025: ("#7C2D12", "#BE123C"),
}


def _clean(text: str) -> str:
    # drop invisible format chars (e.g. U+200E) the base-14 fonts can't render
    return "".join(ch for ch in text if unicodedata.category(ch) != "Cf").strip()


def _fit(text: str, font: str, size: float, min_size: float, width: float, max_lines: int) -> tuple[float, list[str]]:
    """Shrink `text` until it wraps into `max_lines`; ellipsize if even `min_size` is too big."""
    while True:
        lines = simpleSplit(text, font, size, width)
        if len(lines) <= max_lines or size <= min_size:
            break
        size -= 0.5
    if len(lines) > max_lines:
        lines = lines[:max_lines]
        last = lines[-1]
        while last and simpleSplit(last + "…", font, size, width) != [last + "…"]:
            last = last[:-1]
        lines[-1] = last.rstrip() + "…"
    return size, lines


def _text_block(
    c: Canvas, text: str, font: str, size: float, min_size: float, max_lines: int, cx: float, cy: float, width: float
):
    """Draws wrapped text centered horizontally on cx and vertically on cy."""
    size, lines = _fit(_clean(text), font, size, min_size, width, max_lines)
    leading = size * 1.15
    top = cy + (len(lines) - 1) * leading / 2 - size * 0.35
    c.setFont(font, size)
    for i, line in enumerate(lines):
        c.drawCentredString(cx, top - i * leading, line)


def _clip_card(c: Canvas, x: float, y: float):
    p = c.beginPath()
    p.rect(x, y, CARD, CARD)
    c.clipPath(p, stroke=0, fill=0)


def draw_front(c: Canvas, x: float, y: float, song: Song, qr_data: str):
    cx = x + CARD / 2
    c.saveState()
    c.setStrokeColor(GUIDE)
    c.setLineWidth(0.6)
    c.roundRect(x + 0.25 * cm, y + 0.25 * cm, CARD - 0.5 * cm, CARD - 0.5 * cm, 0.35 * cm)

    qr = QrCodeWidget(qr_data, barFillColor=INK, barBorder=0)
    x0, y0, x1, y1 = qr.getBounds()
    size = 4.2 * cm
    d = Drawing(size, size, transform=[size / (x1 - x0), 0, 0, size / (y1 - y0), 0, 0])
    d.add(qr)
    renderPDF.draw(d, c, cx - size / 2, y + (CARD - size) / 2)

    c.setFillColor(MUTED)
    c.setFont("Helvetica", 5.5)
    c.drawRightString(x + CARD - 0.5 * cm, y + 0.5 * cm, f"#{song.id}")
    c.restoreState()


def draw_back(c: Canvas, x: float, y: float, song: Song):
    cx, inner = x + CARD / 2, CARD - 2 * PAD
    period = None if song.year is None else min(max(song.year // 5 * 5, 1950), 2025)
    start, end = PERIOD_COLORS[period]

    c.saveState()
    _clip_card(c, x, y)
    c.linearGradient(x, y + CARD, x + CARD, y, (HexColor(start), HexColor(end)), extend=True)

    # vinyl grooves in the corner
    c.setStrokeColor(white)
    c.setStrokeAlpha(0.08)
    c.setLineWidth(0.8)
    for r in range(8, 100, 7):
        c.circle(x + CARD, y, r * 1.6)

    c.setFillColor(white)
    _text_block(c, song.artist, "Helvetica-Bold", 12, 7, 3, cx, y + CARD * 0.79, inner)
    if song.year is None:
        # no year to show: the title takes its place in the middle
        _text_block(c, song.title, "Helvetica-Bold", 18, 9, 3, cx, y + CARD * 0.45, inner)
    else:
        c.setFont("Helvetica-Bold", 46)
        c.drawCentredString(cx, y + CARD / 2 - 46 * 0.35, str(song.year))
        _text_block(c, song.title, "Helvetica-Oblique", 11, 7, 3, cx, y + CARD * 0.23, inner)
    if song.album and song.album != song.title:
        c.setFillAlpha(0.7)
        _text_block(c, song.album, "Helvetica", 6.5, 5, 1, cx, y + PAD * 0.75, inner)
    c.restoreState()


def _cut_marks(c: Canvas):
    c.saveState()
    c.setStrokeColor(MUTED)
    c.setLineWidth(0.4)
    xs = [MARGIN_X + i * CARD for i in range(COLS + 1)]
    ys = [MARGIN_Y + i * CARD for i in range(ROWS + 1)]
    for x in xs:
        c.line(x, 0.3 * cm, x, MARGIN_Y - 0.15 * cm)
        c.line(x, PAGE_H - MARGIN_Y + 0.15 * cm, x, PAGE_H - 0.3 * cm)
    for y in ys:
        c.line(0.15 * cm, y, MARGIN_X - 0.15 * cm, y)
        c.line(PAGE_W - MARGIN_X + 0.15 * cm, y, PAGE_W - 0.15 * cm, y)
    c.restoreState()


def _cell(i: int, mirrored: bool) -> tuple[float, float]:
    col, row = i % COLS, i // COLS
    if mirrored:  # backs are flipped on the long edge when printed duplex
        col = COLS - 1 - col
    return MARGIN_X + col * CARD, PAGE_H - MARGIN_Y - (row + 1) * CARD


def create_pdf(songs: list[Song], path: Path, qr_prefix: str, label: str):
    c = Canvas(str(path), pagesize=A4)
    c.setTitle(f"{label} – TrackStar cards")
    c.setAuthor("TrackStar")
    per_page = COLS * ROWS
    for start in range(0, len(songs), per_page):
        page = songs[start : start + per_page]

        c.setStrokeColor(GUIDE)
        c.setLineWidth(0.5)
        c.grid([MARGIN_X + i * CARD for i in range(COLS + 1)], [MARGIN_Y + i * CARD for i in range(ROWS + 1)])
        for i, song in enumerate(page):
            draw_front(c, *_cell(i, False), song, f"{qr_prefix}{song.id}")
        _cut_marks(c)
        c.showPage()

        for i, song in enumerate(page):
            draw_back(c, *_cell(i, True), song)
        _cut_marks(c)
        c.showPage()
    c.save()
