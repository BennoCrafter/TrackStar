import shutil
from typing import Optional
import click
import json
from pathlib import Path
from generation.card_generator.generate_song_card import generate_song_card
from generation.card_generator.card_generator import convert_songs_to_image_cards
from generation.pdf_generator.generate_pdf import PDFCreator
from generation.qr_code_generator.code_generation import generate_qr_code, generate_qr_codes
from generation.models.song import Song

dataset_template = Path("dataset_template")

def print_separator():
    print("\n" + "="*50 + "\n")

def print_success(message: str):
    print(f"\033[92m✓ {message}\033[0m")

def print_info(message: str):
    print(f"\033[94mℹ {message}\033[0m")

@click.group()
def cli():
    pass

@cli.command()
@click.option('--dataset', type=Path, help='Path to the JSON dataset file', required=True)
@click.option('--output', type=Path, help='Path to the output directory', required=False)
@click.option("--name", type=str, help='Identifier for the dataset', required=False)
@click.option("--display-name", type=str, help='Display name of the dataset', required=True)
def quick_dataset_generator(dataset: Path, output: Path, name: Optional[str], display_name: str):
    if not dataset.exists():
        print(f"\033[91m✗ Dataset file {dataset} does not exist\033[0m")
        return
    if name is None:
        name = dataset.stem
    if output is None:
        output = Path.cwd().parent / "datasets"
        if not output.exists():
            output.mkdir()

    tokens = {"name": name, "display_name": display_name}

    dataset_output = output / name
    pdf_output = dataset_output / "cards.pdf"
    songs_json_path = dataset_output / "songs.json"

    print_separator()
    print_info("Initializing Dataset Generation")
    print_separator()

    # parse json to dataclass
    with open(dataset, 'r') as f:
        json_data = json.load(f)
        songs = [Song(**song) for song in json_data]

    print_info(f"Found {len(songs)} songs in '{name}'")
    print_info(f"Dataset will be created at: {dataset_output.absolute()}")
    print_separator()

    # copy template files
    shutil.copytree(dataset_template, dataset_output)
    replace_tokens(dataset_output / "README.md", tokens)
    replace_tokens(dataset_output / "info.json", tokens)
    qr_codes_path = dataset_output / "raw" / "qr_codes"
    song_cards_path = dataset_output / "raw" / "song_cards"

    shutil.copy(dataset, songs_json_path)
    print_success(f"Dataset copied: {dataset} → {songs_json_path}")

    convert_songs_to_image_cards(songs, song_cards_path)
    print_success(f"Generated {len(songs)} song cards: {song_cards_path}")

    generate_qr_codes(prefix=f"{name};id=", id_range=range(1, len(songs)+1), output_dir=qr_codes_path, file_format="png", scale=6)
    print_success(f"Generated {len(songs)} QR codes: {qr_codes_path}")

    print_separator()
    print_info(f"Generating PDF: {name}.pdf")
    pdf_creator = PDFCreator(pdf_output, qr_codes_path, song_cards_path, 1, len(songs))
    pdf_creator.create_pdf()
    print_success(f"PDF created at: {pdf_output.absolute()}")
    print_separator()

    # Zip raw directory
    raw_path = dataset_output / "raw"
    shutil.make_archive(str(raw_path), 'zip', raw_path)
    shutil.rmtree(raw_path)
    print_success(f"Created archive: {raw_path}.zip")


def replace_tokens(file_path: Path, tokens: dict[str, str]):
    with open(file_path, "r+") as f:
        content = f.read()
        for token, value in tokens.items():
            v = value if value is not None else "null"
            content = content.replace("${" + token + "}", v)
        f.seek(0)
        f.write(content)
        f.truncate()

if __name__ == '__main__':
    cli()
