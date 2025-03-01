from PIL.Image import merge
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from models.cards.image_card import ImageCard
from models.cards.song_card import SongCard
from models.cards.card import Card
import json
from pathlib import Path

class CardConfig:
    def __init__(self, width, height, card_width, card_height, column_gap, row_gap):
        self.width = width
        self.height = height
        self.card_width = card_width
        self.card_height = card_height
        self.column_gap = column_gap
        self.row_gap = row_gap
        self.horizontal_margin = (width - (2 * card_width) - column_gap) / 2
        self.vertical_margin = (height - (4 * card_height) - 3 * row_gap) / 2

    def get_config(self):
        return [
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (0 + 1) * self.card_height - 0 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (1 + 1) * self.card_height - 1 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (2 + 1) * self.card_height - 2 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (3 + 1) * self.card_height - 3 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (0 + 1) * self.card_height - 0 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (1 + 1) * self.card_height - 1 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (2 + 1) * self.card_height - 2 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (3 + 1) * self.card_height - 3 * self.row_gap, width=self.card_width, height=self.card_height)
        ]
class PDFCreator:
    def __init__(self):
        # Dimensions
        self.width, self.height = A4

        # Card and margin dimensions
        self.card_width = 7 * cm
        self.card_height = 7 * cm

        self.column_gap = 1 * cm
        self.row_gap = 0.5 * cm
        self.chunk_size = 8
        self.puffer = 0.5 * cm

        self.line_width = 1

        self.card_config_obj = CardConfig(self.width, self.height, self.card_width, self.card_height, self.column_gap, self.row_gap)
        self.card_config = self.card_config_obj.get_config()


    def get_all_qr_codes_paths(self, base_path: str, qr_range: range) -> list[str]:
        w = []
        for i in qr_range:
            w.append(f"{base_path}/code-{i}.png")

        return sorted(w, key=lambda x: int(x.split('-')[-1].split('.')[0]))

    def get_all_song_cards(self, base_path: str, song_range: range) -> list[str]:
        w = []
        for i in song_range:
            w.append(f"{base_path}/card-{i}.png")

        return sorted(w, key=lambda x: int(x.split('-')[-1].split('.')[0]))

    def add_grid(self, canvas: canvas.Canvas):
        canvas.setStrokeColor(colors.blue)
        canvas.setLineWidth(self.line_width)

        for card in self.card_config:
            # vertical lines
            canvas.line(card.x, 0, card.x, self.height)
            canvas.line(card.x + self.card_width, 0, card.x + self.card_width, self.height)

            # horizontal lines
            canvas.line(0, card.y, self.width, card.y)
            canvas.line(0, card.y + self.card_height, self.width, card.y + self.card_height)

    # PDF generation
    def create_pdf(self, pdf_name: str):
        pdf_canvas = canvas.Canvas(pdf_name, pagesize=A4)
        pdf_canvas.setLineWidth(self.line_width)
        r = range(1, 9)
        qr_codes_paths = self.get_all_qr_codes_paths("/Users/benno/coding/TrackStar/backend/generation/qr_code_generator/out", r)
        song_card_paths = self.get_all_song_cards("/Users/benno/coding/TrackStar/backend/generation/card_generator/out", r)

        image_chunks = [qr_codes_paths[i:i + self.chunk_size] for i in range(0, len(qr_codes_paths), self.chunk_size)]
        song_card_chunks = [song_card_paths[i:i + self.chunk_size] for i in range(0, len(song_card_paths), self.chunk_size)]


        for i in range(len(song_card_chunks)):
            # QR code page
            self.add_grid(pdf_canvas)

            self.create_qr_codes_page(pdf_canvas, image_chunks[i])

            pdf_canvas.showPage()

            # Text page
            self.add_grid(pdf_canvas)
            self.create_songs_page(pdf_canvas, song_card_chunks[i])

            pdf_canvas.showPage()

        pdf_canvas.save()

    def create_qr_codes_page(self, canvas, image_paths: list[str]):
        mirror_qr_codes = True
        if mirror_qr_codes:
            image_paths = image_paths[4:] + image_paths[:4]
        for i, cf in enumerate(self.card_config):
            if i >= len(image_paths):
                return
            c = ImageCard(cf.x - 0.5, cf.y - 0.5, cf.width + 1, cf.height + 1, image_paths[i])
            c.draw(canvas)

    def create_songs_page(self, canvas, image_paths: list[str]):
        for i, cf in enumerate(self.card_config):
            if i >= len(image_paths):
                return
            c = SongCard(cf.x - self.line_width, cf.y - self.line_width, cf.width + self.line_width * 2, cf.height + self.line_width * 2, image_paths[i])
            c.draw(canvas)


if __name__ == "__main__":
    creator = PDFCreator()
    creator.create_pdf("cards.pdf")
