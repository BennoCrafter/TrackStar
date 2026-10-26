"""Renders card-design.json into a printable, duplex-ready cards.pdf.

The design file is shared with the app (TrackStar/Datasets/CardPrinter.swift), which renders the same
PDF from it. Format and rendering rules: see README.md, "Card design format". Change both renderers together.
"""

import json
import unicodedata
from pathlib import Path

from reportlab.graphics.barcode import qrencoder
from reportlab.lib.colors import Color, HexColor
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen.canvas import Canvas
from songs import Song

DESIGN_DIR = Path(__file__).resolve().parent.parent / "TrackStar" / "Resources" / "CardDesign"
DESIGN = json.loads((DESIGN_DIR / "card-design.json").read_text())
for _key, _file in DESIGN["fonts"].items():
    pdfmetrics.registerFont(TTFont(f"card-{_key}", str(DESIGN_DIR / _file)))


def _color(name: str) -> Color:
    return HexColor(DESIGN["colors"].get(name, name))


def period_colors(year: int | None) -> list[str]:
    periods = DESIGN["periods"]
    if year is None:
        return periods["none"]
    keys = sorted(int(k) for k in periods["colors"])
    return periods["colors"][str(min(max(year // periods["step"] * periods["step"], keys[0]), keys[-1]))]


# MARK: text


def _clean(text: str) -> str:
    text = "".join(" " if ch in "\t\n\r" else ch for ch in text)
    return "".join(ch for ch in text if unicodedata.category(ch) != "Cf").strip(" ")


def _width(text: str, font: str, size: float) -> float:
    return pdfmetrics.stringWidth(text, font, size)


def _wrap(text: str, font: str, size: float, width: float) -> list[str]:
    lines: list[str] = []
    for word in [w for w in text.split(" ") if w]:
        if lines and _width(lines[-1] + " " + word, font, size) <= width:
            lines[-1] += " " + word
        else:
            lines.append(word)
    return lines


def fit(text: str, font: str, size: float, min_size: float, width: float, max_lines: int) -> tuple[float, list[str]]:
    """Shrink by 0.5 pt until the text wraps into `max_lines`; ellipsize if even `min_size` is too big."""
    while True:
        lines = _wrap(text, font, size, width)
        if len(lines) <= max_lines or size - 0.5 < min_size:
            break
        size -= 0.5
    if len(lines) > max_lines:
        lines = lines[:max_lines]
        last = lines[-1]
        while last and _width(last + "…", font, size) > width:
            last = last[:-1]
        lines[-1] = last.rstrip(" ") + "…"
    return size, lines


# MARK: QR code


def _penalty(m: list[list[bool]]) -> int:
    n, score = len(m), 0
    for grid in (m, [list(col) for col in zip(*m)]):
        for row in grid:
            run = 1
            for i in range(1, n + 1):
                if i < n and row[i] == row[i - 1]:
                    run += 1
                    continue
                if run >= 5:
                    score += run - 2
                run = 1
            bits = "".join("1" if b else "0" for b in row)
            for pattern in ("10111010000", "00001011101"):
                score += 40 * sum(bits.startswith(pattern, i) for i in range(n))
    score += 3 * sum(m[r][c] == m[r][c + 1] == m[r + 1][c] == m[r + 1][c + 1] for r in range(n - 1) for c in range(n - 1))
    dark, total = sum(map(sum, m)), n * n
    score += ((abs(dark * 20 - total * 10) + total - 1) // total - 1) * 10
    return score


def qr_modules(text: str) -> list[list[bool]]:
    """Byte mode, level M, smallest version, the mask with the lowest penalty (first on ties); no quiet zone."""
    best = None
    for mask in range(8):
        qr = qrencoder.QRCode(None, qrencoder.QRErrorCorrectLevel.M)
        qr.addData(qrencoder.QR8bitByte(text))
        qr.version = qr.calculate_version()
        qr.makeImpl(False, mask)
        m = [[bool(qr.isDark(r, c)) for c in range(qr.getModuleCount())] for r in range(qr.getModuleCount())]
        score = _penalty(m)
        if best is None or score < best[0]:
            best = (score, m)
    return best[1]


# MARK: drawing


def _fields(song: Song, dataset: str) -> dict[str, str]:
    values = {"dataset": dataset, "id": song.id, "title": song.title, "artist": song.artist, "year": song.year, "album": song.album}
    return {k: "" if v is None else str(v) for k, v in values.items()}


def _holds(condition: str, f: dict[str, str]) -> bool:
    if "!=" in condition:
        a, b = (s.strip() for s in condition.split("!="))
        return f[a] != f[b]
    if condition.startswith("!"):
        return not f[condition[1:]]
    return bool(f[condition])


def _draw_card(c: Canvas, elements: list[dict], x0: float, top: float, f: dict[str, str], year: int | None):
    """Card coordinates are mm from the card's top-left corner, y down; the PDF is pt, y up."""

    def px(x):
        return x0 + x * mm

    def py(y):
        return top - y * mm

    card = DESIGN["sheet"]["card"] * mm
    c.saveState()
    clip = c.beginPath()
    clip.rect(x0, top - card, card, card)
    c.clipPath(clip, stroke=0, fill=0)
    for e in elements:
        if not all(_holds(cond, f) for cond in e.get("if", [])):
            continue
        c.saveState()
        if "rect" in e and "qr" not in e:
            x, y, w, h = e["rect"]
            c.setStrokeColor(_color(e["stroke"]))
            c.setLineWidth(e["lineWidth"])
            # circular corners (Canvas.roundRect isn't: its control points use 0.4472 instead of 0.5523)
            r, left, bottom, right, top_ = e.get("radius", 0) * mm, px(x), py(y + h), px(x + w), py(y)
            p = c.beginPath()
            p.arc(right - 2 * r, bottom, right, bottom + 2 * r, -90, 90)
            p.arcTo(right - 2 * r, top_ - 2 * r, right, top_, 0, 90)
            p.arcTo(left, top_ - 2 * r, left + 2 * r, top_, 90, 90)
            p.arcTo(left, bottom, left + 2 * r, bottom + 2 * r, 180, 90)
            p.close()
            c.drawPath(p, stroke=1, fill=0)
        elif "gradient" in e:
            start, end = period_colors(year)
            c.linearGradient(px(e["from"][0]), py(e["from"][1]), px(e["to"][0]), py(e["to"][1]), (HexColor(start), HexColor(end)), extend=True)
        elif "rings" in e:
            c.setStrokeColor(_color(e["stroke"]))
            c.setStrokeAlpha(e.get("opacity", 1))
            c.setLineWidth(e["lineWidth"])
            for i in range(e["count"]):
                c.circle(px(e["rings"][0]), py(e["rings"][1]), (e["radius"] + i * e["step"]) * mm, stroke=1, fill=0)
        elif "qr" in e:
            x, y, w, _ = e["rect"]
            m = qr_modules(e["qr"].format(**f))
            s = w * mm / len(m)
            c.setFillColor(_color(e["color"]))
            path = c.beginPath()
            for r, row in enumerate(m):
                for col, dark in enumerate(row):
                    if dark:
                        path.rect(px(x) + col * s, py(y) - (r + 1) * s, s, s)
            c.drawPath(path, stroke=0, fill=1)
        elif "text" in e:
            font = f"card-{e['font']}"
            x, cy, w = e["box"]
            size, lines = fit(_clean(e["text"].format(**f)), font, e["size"], e.get("minSize", e["size"]), w * mm, e.get("maxLines", 1))
            leading = size * 1.15
            baseline = py(cy) + (len(lines) - 1) * leading / 2 - size * 0.35
            c.setFillColor(_color(e["color"]))
            c.setFillAlpha(e.get("opacity", 1))
            c.setFont(font, size)
            align = e.get("align", "center")
            for i, line in enumerate(lines):
                lw = _width(line, font, size)
                lx = {"left": px(x), "center": px(x) + (w * mm - lw) / 2, "right": px(x) + w * mm - lw}[align]
                c.drawString(lx, baseline - i * leading, line)
        c.restoreState()
    c.restoreState()


def _sheet_lines(c: Canvas, fronts: bool):
    s = DESIGN["sheet"]
    page_w, page_h, card = s["page"][0] * mm, s["page"][1] * mm, s["card"] * mm
    mx, my = (page_w - s["cols"] * card) / 2, (page_h - s["rows"] * card) / 2
    xs = [mx + i * card for i in range(s["cols"] + 1)]
    ys = [my + i * card for i in range(s["rows"] + 1)]
    lines = []
    if fronts:
        lines += [(x, ys[0], x, ys[-1]) for x in xs] + [(xs[0], y, xs[-1], y) for y in ys]
        c.setStrokeColor(_color(s["grid"]["color"]))
        c.setLineWidth(s["grid"]["lineWidth"])
        c.lines(lines)
    m = s["cutMarks"]
    ex, ey, gap = m["edge"][0] * mm, m["edge"][1] * mm, m["gap"] * mm
    marks = [(x, ey, x, my - gap) for x in xs] + [(x, page_h - my + gap, x, page_h - ey) for x in xs]
    marks += [(ex, y, mx - gap, y) for y in ys] + [(page_w - mx + gap, y, page_w - ex, y) for y in ys]
    c.setStrokeColor(_color(m["color"]))
    c.setLineWidth(m["lineWidth"])
    c.lines(marks)


def create_pdf(songs: list[Song], path: Path, dataset: str, label: str):
    s = DESIGN["sheet"]
    page_w, page_h, card = s["page"][0] * mm, s["page"][1] * mm, s["card"] * mm
    mx, my = (page_w - s["cols"] * card) / 2, (page_h - s["rows"] * card) / 2
    c = Canvas(str(path), pagesize=(page_w, page_h), invariant=True)
    c.setTitle(DESIGN["title"].format(label=label))
    c.setCreator("TrackStar")
    per_page = s["cols"] * s["rows"]
    for start in range(0, len(songs), per_page):
        sheet = songs[start : start + per_page]
        for backs in (False, True):
            c.saveState()
            _sheet_lines(c, fronts=not backs)
            c.restoreState()
            for i, song in enumerate(sheet):
                col, row = i % s["cols"], i // s["cols"]
                if backs:  # flipped on the long edge when printed duplex
                    col = s["cols"] - 1 - col
                elements = DESIGN["back" if backs else "front"]
                _draw_card(c, elements, mx + col * card, page_h - my - row * card, _fields(song, dataset), song.year)
            c.showPage()
    c.save()


if __name__ == "__main__":
    # self-check: wrapping, ellipsis, period lookup, QR shape
    assert fit("a b c", "card-regular", 10, 10, 1000, 1) == (10, ["a b c"])
    size, lines = fit("word " * 40, "card-bold", 12, 7, 100, 3)
    assert size == 7 and len(lines) == 3 and lines[-1].endswith("…")
    assert period_colors(1949) == DESIGN["periods"]["colors"]["1950"] and period_colors(2099) == DESIGN["periods"]["colors"]["2025"]
    assert period_colors(1987) == DESIGN["periods"]["colors"]["1985"] and period_colors(None) == DESIGN["periods"]["none"]
    assert len(qr_modules("trackstar://hitster/?id=12")) == 25
    print("ok")
