import cairosvg
import textwrap
from pathlib import Path
from typing import Optional
from xml.sax.saxutils import escape
from song import Song

width, height = 700, 700
max_chars_per_line = 20
line_spacing = 60

def generate_song_card(song: Song, output_path: Path) -> Path:
    """
    Generates an SVG song card and converts it to PNG.

    Args:
        song: The song object.
        output_path: The desired output path or folder for the PNG file.
    """
    output_file = output_path if not output_path.is_dir() else output_path / f"card-{song.id}.png"
    wrapped_title = textwrap.wrap(song.title, max_chars_per_line)
    wrapped_author = textwrap.wrap(f"{song.artist}", max_chars_per_line)
    wrapped_year = textwrap.wrap(f"{song.year}", max_chars_per_line)

    def create_multiline_text(lines, start_y, font_size, color):
        text_elements = []
        for i, line in enumerate(lines):
            y_pos = start_y + (i * line_spacing)
            text_elements.append(f'<text x="50%" y="{y_pos}" font-size="{font_size}" font-family="Arial" text-anchor="middle" fill="{color}">{escape(line)}</text>')
        return "\n".join(text_elements)

    title_start_y = 200 - (len(wrapped_title) * line_spacing // 2)
    author_start_y = title_start_y + (len(wrapped_title) * line_spacing) + 80
    year_start_y = author_start_y + (len(wrapped_author) * line_spacing) + 50

    # Construct SVG
    svg_content = f"""
    <svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg">
        <!-- Background -->
        <rect width="100%" height="100%" fill="white"/>

        <!-- Wrapped Title -->
        {create_multiline_text(wrapped_title, title_start_y, 60, "black")}

        <!-- Wrapped Artist -->
        {create_multiline_text(wrapped_author, author_start_y, 40, "black")}

        <!-- Wrapped Year -->
        {create_multiline_text(wrapped_year, year_start_y, 40, "black")}
    </svg>
    """

    cairosvg.svg2png(bytestring=svg_content.encode('utf-8'), write_to=str(output_file.absolute()), output_width=width, output_height=height)

    return output_file
