"""Taylor Swift album/lyrics dump (resources/album-song-lyrics.json) → songs.json"""

import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("input", type=Path, nargs="?", default=Path(__file__).parent / "resources/album-song-lyrics.json")
parser.add_argument("-o", "--output", type=Path, default=Path("songs.json"))
args = parser.parse_args()

tracks = [
    (song["Title"], era["Title"], era["Year"])
    for era in json.loads(args.input.read_text())
    if era.get("Code") != "OTH"  # skip non-album releases
    for song in era["Songs"]
]
songs = [
    {"id": i, "title": title, "artist": "Taylor Swift", "year": year, "album": album}
    for i, (title, album, year) in enumerate(tracks, 1)
]

args.output.write_text(json.dumps(songs, indent=2, ensure_ascii=False) + "\n")
print(f"{len(songs)} songs → {args.output}")
