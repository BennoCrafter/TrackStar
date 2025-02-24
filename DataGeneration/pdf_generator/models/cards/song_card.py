from reportlab.pdfgen.canvas import Canvas
from models.cards.card import Card
from pathlib import Path

class SongCard(Card):
    def __init__(self, x: float, y: float, width: float, height: float, image_path: str | Path) -> None:
        super().__init__(x, y, width, height)
        self.image_path = image_path

    def draw(self, canvas: Canvas):
        super().draw(canvas)

        # Draw the image with the scaled dimensions, centered
        canvas.drawImage(self.image_path, self.x, self.y, self.width, self.height)
