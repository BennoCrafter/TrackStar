from enum import CONFORM
from typing import Any, Optional, Sequence
from PIL.Image import merge
from click import Context
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from generation.pdf_generator.models.cards.image_card import ImageCard
from generation.pdf_generator.models.cards.song_card import SongCard
from generation.pdf_generator.models.cards.card import Card
import json
from pathlib import Path
import argparse
import math

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
            [
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (0 + 1) * self.card_height - 0 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (1 + 1) * self.card_height - 1 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (2 + 1) * self.card_height - 2 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 0 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (3 + 1) * self.card_height - 3 * self.row_gap, width=self.card_width, height=self.card_height),
            ],
            [
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (0 + 1) * self.card_height - 0 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (1 + 1) * self.card_height - 1 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (2 + 1) * self.card_height - 2 * self.row_gap, width=self.card_width, height=self.card_height),
            Card(x=self.horizontal_margin + 1 * (self.card_width + self.column_gap), y=self.height - self.vertical_margin - (3 + 1) * self.card_height - 3 * self.row_gap, width=self.card_width, height=self.card_height)
            ]
        ]

class PDFCreator:
    def __init__(self, pdf_name: str | Path, qr_code_path: Path, song_card_path: Path, start_index: int, end_index: int, card_width: float = 7, card_height: float = 7, column_gap: float = 1, row_gap: float = 0.5, mirror_qr_codes: bool = True):
        # Dimensions
        self.width, self.height = A4
        self.pdf_name = pdf_name

        # Card and margin dimensions
        self.card_width = card_width * cm
        self.card_height = card_height * cm

        self.column_gap = column_gap * cm
        self.row_gap = row_gap * cm
        self.chunk_size = 8
        self.puffer = 0.5 * cm

        self.line_width = 1

        self.qr_code_path = qr_code_path
        self.song_card_path = song_card_path
        self.start_index = start_index
        self.end_index = end_index
        self.mirror_qr_codes = mirror_qr_codes

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

    @staticmethod
    def get_all_files(base_path: Path) -> list[Path]:
        files = [f for f in base_path.iterdir() if f.is_file()]
        return sorted(files, key=lambda x: int(x.name.split('-')[-1].split('.')[0]))

    def add_grid(self):
        self.pdf_canvas.setLineWidth(self.line_width)

        for card in self.flatten(self.card_config):
            # vertical lines
            self.pdf_canvas.line(card.x, 0, card.x, self.height)
            self.pdf_canvas.line(card.x + self.card_width, 0, card.x + self.card_width, self.height)

            # horizontal lines
            self.pdf_canvas.line(0, card.y, self.width, card.y)
            self.pdf_canvas.line(0, card.y + self.card_height, self.width, card.y + self.card_height)

    @staticmethod
    def flatten(lst: list[list[Any]]) -> list[Any]:
        return [item for sublist in lst for item in sublist]

    @staticmethod
    def chunkinize(lst: list[Any], n: int):
        new = []
        for i in range(0, len(lst), n):
            new.append(lst[i:i+n])
        return new

    @staticmethod
    def fill_left(lst_len: int, l: int) -> list[Any]:
        pad_count = (math.ceil(lst_len / l) * l) - lst_len
        return [None] * pad_count

    def colum_chunkinize(self, lst: list[Any], n: int) -> list[list[list[Any]]]:
        return [self.chunkinize(l, n // 2) for l in self.chunkinize(lst, n)]


    # PDF generation
    def create_pdf(self):
        i = self.get_all_files(self.qr_code_path)
        qr_codes_paths: Sequence[Optional[Path]] = i + self.fill_left(len(i), self.chunk_size)
        i = self.get_all_files(self.song_card_path)
        song_cards_paths: Sequence[Optional[Path]] = i + self.fill_left(len(i), self.chunk_size)
        song_card_chunks: list[list[list[Path]]] = self.colum_chunkinize(song_cards_paths, self.chunk_size)
        image_chunks: list[list[list[Path]]] = self.colum_chunkinize(qr_codes_paths, self.chunk_size)

        for i in range(len(song_card_chunks)):
            if self.mirror_qr_codes:
                image_chunks[i] = image_chunks[i][::-1]

            self.create_page(image_chunks[i])
            self.create_page(song_card_chunks[i])

        self.pdf_canvas.save()

    def create_page(self, image_paths: Sequence[list[Path]]): # eg. [[1,2,3,4], [5,6,7,8]]
        self.add_grid()

        for col_index, col in enumerate(self.card_config):
            for row_index, card in enumerate(col):
                if image_paths[col_index][row_index] is None:
                    continue
                image_card = ImageCard.from_card(card, image_paths[col_index][row_index], self.line_width)
                image_card.draw(self.pdf_canvas)

        self.pdf_canvas.showPage()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create a PDF of cards.")
    parser.add_argument("-o", "--pdf_name", type=str, help="Name of the output PDF file.", default="out/cards.pdf")
    parser.add_argument("-q", "--qr_code_path", type=Path, help="Base path for QR code images.", default="out/qr_codes")
    parser.add_argument("-s", "--song_card_path", type=Path, help="Base path for song card images.", default="out/song_cards")
    parser.add_argument("-i", "--start_index", type=int, help="Starting index for cards.", default=0)
    parser.add_argument("-e", "--end_index", type=int, help="Ending index for cards.")
    parser.add_argument("-cw", "--card_width", type=float, default=7, help="Width of each card in cm. Default is 7cm.")
    parser.add_argument("-ch", "--card_height", type=float, default=7, help="Height of each card in cm. Default is 7cm.")
    parser.add_argument("-c", "--column_gap", type=float, default=1, help="Gap between columns in cm. Default is 1cm.")
    parser.add_argument("-r", "--row_gap", type=float, default=0.5, help="Gap between rows in cm. Default is 0.5cm.")
    parser.add_argument("-m", "--mirror_qr_codes", type=bool, default=True, help="Whether to mirror the QR codes. Default is True")

    args = parser.parse_args()

    creator = PDFCreator(args.pdf_name, args.qr_code_path, args.song_card_path, args.start_index, args.end_index, args.card_width, args.card_height, args.column_gap, args.row_gap, args.mirror_qr_codes)
    creator.create_pdf()
