import fitz  # PyMuPDF
from pathlib import Path


def pdf_to_png(pdf_path: Path, output_folder: Path, song_card_page: int):
    names: list[str] = ["song_cards", "qr_codes"]
    doc = fitz.open(pdf_path)

    for i, page_num in enumerate([song_card_page, song_card_page + 1]):
        if page_num < len(doc):
            page = doc.load_page(page_num)
            pix = page.get_pixmap(dpi=300)
            output_path = f"{output_folder}/{names[i]}.png"
            pix.save(output_path)

if __name__ == "__main__":
    song_card_page: int = 2
    pdf_path = Path("../../datasets/hitster_songDB/songs.pdf")
    output_folder = Path("../screenshots/dataset")

    pdf_to_png(pdf_path, output_folder, song_card_page)
