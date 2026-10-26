"""Hitster card list (CSV with Card#, Title, Artist, Year) → songs.json"""

import argparse
import csv
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("input", type=Path, nargs="?", default=Path(__file__).parent / "resources/hitster-de.csv")
parser.add_argument("-o", "--output", type=Path, default=Path("songs.json"))
args = parser.parse_args()

with open(args.input, newline="") as f:
    songs = [
        {"id": int(r["Card#"]), "title": r["Title"], "artist": r["Artist"], "year": int(r["Year"]), "album": None}
        for r in csv.DictReader(f)
        if r.get("Card#") and r.get("Title") and r.get("Artist") and r.get("Year")
    ]

args.output.write_text(json.dumps(songs, indent=2, ensure_ascii=False) + "\n")
print(f"{len(songs)} songs → {args.output}")
