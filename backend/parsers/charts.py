"""Yearly chart dump (JSON with Rank, Year, Artist, Song Title, Album) + hand-picked 2020-2022 songs → songs.json"""

import argparse
import json
from pathlib import Path

from resources.chatgpted_data import top_songs_2020_to_2022

# max chart rank to include per release-year range
MAX_RANK = {(1956, 1971): 2, (1971, 2019): 15, (2019, 2024): 18}


def max_rank(year: int) -> int:
    return next((r for (lo, hi), r in MAX_RANK.items() if lo <= year < hi), 0)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("input", type=Path)
parser.add_argument("-o", "--output", type=Path, default=Path("songs.json"))
args = parser.parse_args()

rows = [
    (s["Song Title"], s["Artist"], s.get("Album"), int(s["Year"]))
    for s in json.loads(args.input.read_text())
    if int(s.get("Rank", 0)) <= max_rank(int(s["Year"]))
]
rows += [(s["title"], s["artist"], s.get("album"), int(s["year"])) for s in top_songs_2020_to_2022]
songs = [
    {"id": i, "title": title, "artist": artist, "year": year, "album": album}
    for i, (title, artist, album, year) in enumerate(rows, 1)
]

args.output.write_text(json.dumps(songs, indent=2, ensure_ascii=False) + "\n")
print(f"{len(songs)} songs → {args.output}")
