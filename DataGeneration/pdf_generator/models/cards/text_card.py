from reportlab.pdfgen.canvas import Canvas
from models.cards.card import Card

class TextCard(Card):
    def __init__(self, x: float, y: float, width: float, height: float, text: str) -> None:
        super().__init__(x, y, width, height)
        self.text = text

    def draw(self, canvas: Canvas):
        super().draw(canvas)
        canvas.setFont("Helvetica", 12)

        text_width = canvas.stringWidth(self.text, "Helvetica", 12)
        text_height = 12
        font_size = 15

        while text_width > self.width or text_height > self.height:
            font_size -= 1.5  # Decrease the font size
            canvas.setFont("Helvetica", font_size)
            text_width = canvas.stringWidth(self.text, "Helvetica", font_size)
            text_height = font_size

        canvas.drawString(self.x + self.width / 2 - text_width/ 2, self.y + self.height / 2, self.text)
