import json
import re
from pathlib import Path

import click

from cards import create_pdf
from songs import load_songs, save_songs

DATASETS_DIR = Path(__file__).resolve().parent.parent / "datasets"

README = """# {display_name}

The song data from the game is copyrighted by the respective rights holders of each song.
This repository contains only the reference data, not the actual song audio.
"""


@click.group()
def cli():
    pass


@cli.command()
@click.argument("songs_json", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option("--display-name", required=True, help="Human readable dataset name.")
@click.option("--name", required=True, help="Dataset identifier in kebab-case (e.g. taylor-swift), also encoded in the QR codes.")
@click.option("--output", type=Path, default=DATASETS_DIR, show_default=True, help="Parent directory of the dataset.")
@click.option("--increase", is_flag=True, help="Raise the version even if songs and display name are unchanged.")
def build(songs_json: Path, display_name: str, name: str, output: Path, increase: bool):
    """Build a dataset folder (info.json, songs.json, README.md, cards.pdf) from SONGS_JSON."""
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
        raise click.BadParameter("use lowercase kebab-case, e.g. taylor-swift", param_hint="--name")
    out = output / name
    out.mkdir(parents=True, exist_ok=True)

    songs = load_songs(songs_json)
    click.secho(f"ℹ {len(songs)} songs → {out}", fg="blue")

    songs_path, info_path = out / "songs.json", out / "info.json"
    old_songs = songs_path.read_text() if songs_path.exists() else None
    old_info = json.loads(info_path.read_text()) if info_path.exists() else {}
    save_songs(songs, songs_path)

    # the app re-downloads a dataset when its version goes up
    version = old_info.get("version", 0)
    if increase or "version" not in old_info or songs_path.read_text() != old_songs or old_info.get("display_name") != display_name:
        version += 1
        click.secho(f"ℹ version {version}", fg="blue")
    info = {"name": name, "display_name": display_name, "version": version}
    info_path.write_text(json.dumps(info, indent=2) + "\n")
    readme = out / "README.md"
    if not readme.exists():
        readme.write_text(README.format(display_name=display_name))

    write_cards(out, songs, name, display_name)
    click.secho(f"✓ Dataset ready: {out}", fg="green")


@cli.command()
@click.option("--datasets", type=Path, default=DATASETS_DIR, show_default=True, help="Directory containing the datasets.")
def rebuild(datasets: Path):
    """Regenerate cards.pdf of every dataset (e.g. after a card design change). Versions stay the same."""
    for out in sorted(d for d in datasets.iterdir() if (d / "info.json").exists() and (d / "songs.json").exists()):
        info = json.loads((out / "info.json").read_text())
        songs = load_songs(out / "songs.json")
        write_cards(out, songs, info["name"], info.get("display_name") or info["name"])
        click.secho(f"✓ {out.name}: {len(songs)} cards", fg="green")


def write_cards(out: Path, songs, name: str, display_name: str):
    create_pdf(songs, out / "cards.pdf", dataset=name, label=display_name)


if __name__ == "__main__":
    cli()
