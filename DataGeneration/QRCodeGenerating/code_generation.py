import argparse
import os
import pyqrcode
import png
from tqdm import tqdm

def generate_qr_codes(prefix: str, id_range: range, output_dir: str, file_format, scale):
    """Generate QR codes for a range of IDs and save them as images."""

    # Create the output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    for i in tqdm(id_range, unit="qr-code"):
        # Generate the QR code
        data = f"{prefix}{i}"
        url = pyqrcode.create(data)

        # Define the filename for saving
        filename = os.path.join(output_dir, f"code-{i}")

        # Save QR code as either PNG or SVG based on file_format
        if file_format == 'png':
            url.png(f"{filename}.png", scale=scale)
        elif file_format == 'svg':
            url.svg(f"{filename}.svg", scale=scale)
        else:
            print(f"Unsupported file format: {file_format}. Supported formats are 'png' and 'svg'.")
            break

    print(f"Successfully generated {id_range.stop - id_range.start} QR codes and saved in '{output_dir}'")

def main():
    # Create the argument parser
    parser = argparse.ArgumentParser(description="Generate QR codes for a range of IDs.")

    # Add arguments for customizability
    parser.add_argument('--prefix', type=str, default="id=", help="Prefix for the QR code data.")
    parser.add_argument('--start', type=int, default=1, help="Start of the ID range.")
    parser.add_argument('--end', type=int, default=700, help="End of the ID range.")
    parser.add_argument('--output', type=str, default="QRCodes", help="Directory to save the QR code images.")
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
