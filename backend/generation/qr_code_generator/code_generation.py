import argparse
import os
import pyqrcode
from tqdm import tqdm
from PIL import Image
import cairosvg
import textwrap
from pathlib import Path
from typing import Optional
from xml.sax.saxutils import escape
import base64

width, height = 700, 700


def generate_qr_code(data: str, output_file: Path, scale: int, id: int):
    """Generate a QR code for the given data and save it as an image."""

    url = pyqrcode.create(data)

    png_data = url.png_as_base64_str(scale=scale)

    # Create SVG content with base64 PNG
    svg_content = f"""
    <svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg">
        <!-- Background -->
        <rect width="100%" height="100%" fill="white"/>

        <!-- QR Code Image -->
        <image x="100" y="100" width="500" height="500" href="data:image/png;base64,{png_data}" />

        <!-- Song ID (Bottom Right) -->
        <text x="{width - 20}" y="{height - 20}" font-size="20" font-family="Arial" text-anchor="end" fill="gray">{escape(str(id))}</text>
    </svg>
    """

    # Convert the SVG to PNG and save it
    cairosvg.svg2png(bytestring=svg_content.encode('utf-8'), write_to=str(output_file.absolute()), output_width=width, output_height=height)

    return output_file


def generate_qr_codes(prefix: str, id_range: range, output_dir: Path, file_format, scale):
    """Generate QR codes for a range of IDs and save them as images."""

    # Create the output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)

    for i in tqdm(id_range, unit="qr-code", desc=f"Generating QR codes"):
        data = f"{prefix}{i}"
        filename = Path(os.path.join(output_dir, f"code-{i}.{file_format}"))

        generate_qr_code(data, filename, scale, i)

def main():
    # Create the argument parser
    parser = argparse.ArgumentParser(description="Generate QR codes for a range of IDs.")

    # Add arguments for customizability
    parser.add_argument('--prefix', type=str, default="id=", help="Prefix for the QR code data.")
    parser.add_argument('--start', type=int, default=1, help="Start of the ID range.")
    parser.add_argument('--end', type=int, default=700, help="End of the ID range.")
    parser.add_argument('--output', type=str, default="out/qr_codes", help="Directory to save the QR code images.")
    parser.add_argument('--format', choices=['png', 'svg'], default='png', help="Format of the QR code image (png or svg).")
    parser.add_argument('--scale', type=int, default=6, help="Scale for the generated QR codes.")

    # Parse the arguments
    args = parser.parse_args()

    # Generate the range of IDs based on the start and end arguments
    id_range = range(args.start, args.end + 1)

    # Call the function to generate QR codes
    generate_qr_codes(args.prefix, id_range, args.output, args.format, args.scale)


if __name__ == "__main__":
    main()
