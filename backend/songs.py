"""Song model and songs.json IO."""

import json
from dataclasses import asdict, dataclass, fields
from pathlib import Path


@dataclass
class Song:
    id: int
    title: str
    artist: str
    year: int | None = None
    album: str | None = None


def load_songs(path: Path) -> list[Song]:
    known = {f.name for f in fields(Song)}
    songs = [Song(**{k: v for k, v in d.items() if k in known}) for d in json.loads(path.read_text())]
    ids = [s.id for s in songs]
    if len(ids) != len(set(ids)):
        raise ValueError(f"{path}: song ids are not unique")
    return songs


def save_songs(songs: list[Song], path: Path):
    path.write_text(json.dumps([asdict(s) for s in songs], indent=2, ensure_ascii=False) + "\n")
