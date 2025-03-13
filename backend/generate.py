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

@click.group()
def cli():
    pass

@cli.command()
@click.option('--dataset', type=Path, help='Path to the JSON dataset file', required=True)
@click.option('--output', type=Path, help='Path to the output directory', required=False)
@click.option("--name", type=str, help='Name of the dataset', required=False)
def quick_dataset_generator(dataset: Path, output: Path, name: Optional[str]):
    if not dataset.exists():
        click.echo(f"Dataset file {dataset} does not exist")
        return
    if name is None:
        name = dataset.stem
    if output is None:
        output = Path.cwd().parent / "datasets"
        if not output.exists():
            output.mkdir()

    dataset_output = output / name
    # parse json to dataclass
    with open(dataset, 'r') as f:
        json_data = json.load(f)
        songs = [Song(**song) for song in json_data]
        f.close()

    click.echo(f"Found {len(songs)} songs in {name}")
    click.echo(f"Creating dataset '{name}' at {dataset_output.absolute()}")

    # copy template files
    shutil.copytree(dataset_template, dataset_output)
    replace_tokens(dataset_output, name)
    qr_codes_path = dataset_output / "raw" / "qr_codes"
    song_cards_path = dataset_output / "raw" / "song_cards"

    convert_songs_to_image_cards(songs, song_cards_path)
    click.echo(f"Successfully generated {len(songs)} song cards and saved in '{song_cards_path}'")

    generate_qr_codes(prefix=f"{name};id=", id_range=range(1, len(songs)+1), output_dir=qr_codes_path, file_format="png", scale=6)
    click.echo(f"Successfully generated {len(songs)} QR codes and saved in '{qr_codes_path}'")
    pdf_creator = PDFCreator(Path(dataset_output / f"{name}.pdf"), qr_codes_path, song_cards_path, 1, len(songs))
    pdf_creator.create_pdf()
    click.echo(f"Successfully created PDF '{name}.pdf' and saved in '{dataset_output}'")


def replace_tokens(dataset_path: Path, name: str):
    readme_path = dataset_path / "README.md"
    with open(readme_path, "r+") as f:
        readme_content = f.read()
        f.seek(0)
        f.write(readme_content.replace("{$name}", name))
        f.truncate()
        f.close()

if __name__ == '__main__':
    cli()
