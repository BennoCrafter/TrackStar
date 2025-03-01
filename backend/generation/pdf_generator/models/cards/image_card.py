from reportlab.pdfgen.canvas import Canvas
from models.cards.card import Card
from PIL import Image
from pathlib import Path

class ImageCard(Card):
    def __init__(self, x: float, y: float, width: float, height: float, image_path: str | Path) -> None:
        super().__init__(x, y, width, height)
        self.image_path = image_path

    def draw(self, canvas: Canvas):
        super().draw(canvas)

        canvas.drawImage(self.image_path, self.x, self.y, self.width, self.height)

    @classmethod
    def from_card(cls, card: Card, image_path: str | Path, line_width: float | int):
        return cls(card.x - line_width, card.y - line_width, card.width + line_width * 2, card.height + line_width * 2, image_path)
