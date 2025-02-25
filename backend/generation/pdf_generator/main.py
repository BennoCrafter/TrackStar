from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from models.cards.image_card import ImageCard
from models.cards.song_card import SongCard
from models.cards.card import Card
import json
from pathlib import Path

# Dimensions
width, height = A4

# Card and margin dimensions
card_width = 7 * cm
card_height = 7 * cm

column_gap = 0 * cm
chunk_size = 8
puffer = 0.5 *cm

horizontal_margin = (width - (2 * card_width) - column_gap) / 2

vertical_margin = (height - (4 * card_height)) / 2

# Create the card configuration with 8 cards
card_config = [
    # First column (no gap)
    Card(x=horizontal_margin + 0 * card_width, y=height - vertical_margin - (0 + 1) * card_height, width=card_width, height=card_height),
    Card(x=horizontal_margin + 0 * card_width, y=height - vertical_margin - (1 + 1) * card_height, width=card_width, height=card_height),
    Card(x=horizontal_margin + 0 * card_width, y=height - vertical_margin - (2 + 1) * card_height, width=card_width, height=card_height),
    Card(x=horizontal_margin + 0 * card_width, y=height - vertical_margin - (3 + 1) * card_height, width=card_width, height=card_height),

    # Second column (with gap between the columns)
    Card(x=horizontal_margin + card_width + column_gap, y=height - vertical_margin - (0 + 1) * card_height, width=card_width, height=card_height),
    Card(x=horizontal_margin + card_width + column_gap, y=height - vertical_margin - (1 + 1) * card_height, width=card_width, height=card_height),
    Card(x=horizontal_margin + card_width + column_gap, y=height - vertical_margin - (2 + 1) * card_height, width=card_width, height=card_height),
    Card(x=horizontal_margin + card_width + column_gap, y=height - vertical_margin - (3 + 1) * card_height, width=card_width, height=card_height)
]


def get_all_qr_codes_paths(base_path: str, qr_range: range) -> list[str]:
    w = []
    for i in qr_range:
        w.append(f"{base_path}/code-{i}.png")

    return sorted(w, key=lambda x: int(x.split('-')[-1].split('.')[0]))

def get_all_song_cards(base_path: str, song_range: range) -> list[str]:
    w = []
    for i in song_range:
        w.append(f"{base_path}/card-{i}.png")

    return sorted(w, key=lambda x: int(x.split('-')[-1].split('.')[0]))

def get_all_texts(file_path) -> list[str]:
    txts = []

    with open(file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)

    for song in data:
        txts.append(song.get("title"))

    return txts

def add_grid(canvas: canvas.Canvas):
    canvas.setStrokeColor(colors.black)

    for i in range(-1, 4):
        canvas.line(x_cord(i), vertical_margin, x_cord(i), 0)
        canvas.line(x_cord(i), height - vertical_margin, x_cord(i), height)

    for i in range(-1, 4):
        canvas.line(0, y_cord(i), card_width - horizontal_margin - puffer, y_cord(i))
        canvas.line(width, y_cord(i), width - card_width + horizontal_margin + puffer, y_cord(i))


def y_cord(i: int) -> float:
    return height - vertical_margin - (i + 1) * card_height

def x_cord(i: int) -> float:
    return width - horizontal_margin -(i + 1) * card_width

# PDF generation
def create_pdf(pdf_name: str):
    pdf_canvas = canvas.Canvas(pdf_name, pagesize=A4)
    r = range(1, 9)
    qr_codes_paths = get_all_qr_codes_paths("/Users/benno/coding/TrackStar/backend/generation/qr_code_generator/out", r)
    song_card_paths = get_all_song_cards("/Users/benno/coding/TrackStar/backend/generation/card_generator/out", r)

    image_chunks = [qr_codes_paths[i:i + chunk_size] for i in range(0, len(qr_codes_paths), chunk_size)]
    song_card_chunks = [song_card_paths[i:i + chunk_size] for i in range(0, len(song_card_paths), chunk_size)]


    for i in range(len(song_card_chunks)):
        # QR code page
        create_qr_codes_page(pdf_canvas, image_chunks[i])
        add_grid(pdf_canvas)

        pdf_canvas.showPage()

        # Text page
        create_songs_page(pdf_canvas, song_card_chunks[i])
        add_grid(pdf_canvas)

        pdf_canvas.showPage()

    pdf_canvas.save()

def create_qr_codes_page(canvas, image_paths: list[str]):
    for i, cf in enumerate(card_config):
        if i >= len(image_paths):
            return
        c = ImageCard(cf.x, cf.y, cf.width, cf.height, image_paths[i])
        c.draw(canvas)

def create_songs_page(canvas, image_paths: list[str]):
    for i, cf in enumerate(card_config):
        if i >= len(image_paths):
            return
        c = SongCard(cf.x, cf.y, cf.width, cf.height, image_paths[i])
        c.draw(canvas)


create_pdf("cards.pdf")
