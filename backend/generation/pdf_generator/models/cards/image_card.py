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
        # Open the image to get its original size
        with Image.open(self.image_path) as img:
            original_width, original_height = img.size

        # Calculate the new dimensions (70% of the original size)
        new_width = original_width * 0.7
        new_height = original_height * 0.7

        # Calculate centered x and y coordinates
        centered_x = self.x + (self.width - new_width) / 2
        centered_y = self.y + (self.height - new_height) / 2

        # Draw the image with the scaled dimensions, centered
        canvas.drawImage(self.image_path, centered_x, centered_y, new_width, new_height)
