# Import QRCode from pyqrcode
import pyqrcode
import png
from pyqrcode import QRCode
import json

# String which represents the QR code
url = pyqrcode.create("id=2")

# Create and save the svg file naming "myqr.svg"
url.svg("br.svg", scale = 8)

# Create and save the png file naming "myqr.png"
url.png('br.png', scale = 6)
