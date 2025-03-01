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
    def __init__(self, pdf_name: str | Path):
        # Dimensions
        self.width, self.height = A4
        self.pdf_name = pdf_name

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


        self.pdf_canvas = self.setup_canvas()

    def setup_canvas(self):
        if isinstance(self.pdf_name, Path):
            pdf_canvas = canvas.Canvas(str(self.pdf_name.absolute()), pagesize=A4)
        else:
            pdf_canvas = canvas.Canvas(self.pdf_name, pagesize=A4)

        pdf_canvas.setStrokeColor(colors.black)
        pdf_canvas.setLineWidth(self.line_width)
        return pdf_canvas

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

    def add_grid(self):
        self.pdf_canvas.setStrokeColor(colors.blue)
        self.pdf_canvas.setLineWidth(self.line_width)

        for card in self.card_config:
            # vertical lines
            self.pdf_canvas.line(card.x, 0, card.x, self.height)
            self.pdf_canvas.line(card.x + self.card_width, 0, card.x + self.card_width, self.height)

            # horizontal lines
            self.pdf_canvas.line(0, card.y, self.width, card.y)
            self.pdf_canvas.line(0, card.y + self.card_height, self.width, card.y + self.card_height)

    # PDF generation
    def create_pdf(self):
        r = range(1, 9)
        qr_codes_paths = self.get_all_qr_codes_paths("/Users/benno/coding/TrackStar/backend/out/qr-codes", r)
        song_card_paths = self.get_all_song_cards("/Users/benno/coding/TrackStar/backend/generation/card_generator/out", r)

        image_chunks = [qr_codes_paths[i:i + self.chunk_size] for i in range(0, len(qr_codes_paths), self.chunk_size)]
        song_card_chunks = [song_card_paths[i:i + self.chunk_size] for i in range(0, len(song_card_paths), self.chunk_size)]


        for i in range(len(song_card_chunks)):
            # QR code page
            self.add_grid()

            self.create_qr_codes_page(self.pdf_canvas, image_chunks[i])

            self.pdf_canvas.showPage()

            # Text page
            self.add_grid()
            self.create_songs_page(self.pdf_canvas, song_card_chunks[i])

            self.pdf_canvas.showPage()

        self.pdf_canvas.save()

    def create_qr_codes_page(self, canvas, image_paths: list[str]):
        mirror_qr_codes = True
        if mirror_qr_codes:
            image_paths = image_paths[self.chunk_size//2:] + image_paths[:self.chunk_size//2]
        for i, card in enumerate(self.card_config):
            if i >= len(image_paths):
                return
            image_card = ImageCard.from_card(card, image_paths[i], self.line_width)
            image_card.draw(canvas)

    def create_songs_page(self, canvas, image_paths: list[str]):
        for i, card in enumerate(self.card_config):
            if i >= len(image_paths):
                return
            image_card = ImageCard.from_card(card, image_paths[i], self.line_width)
            image_card.draw(canvas)


if __name__ == "__main__":
    creator = PDFCreator("cards.pdf")
    creator.create_pdf()
