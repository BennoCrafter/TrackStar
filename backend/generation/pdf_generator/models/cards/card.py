from reportlab.pdfgen.canvas import Canvas
from reportlab.lib import colors


class Card:
    def __init__(self, x: float, y: float, width: float, height: float) -> None:
        self.x = x
        self.y = y
        self.width = width
        self.height = height

    def draw(self, canvas: Canvas):
        canvas.setStrokeColor(colors.blue)
        # canvas.rect(self.x, self.y, self.width, self.height)
        canvas.setStrokeColor(colors.black)
