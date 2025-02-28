from dataclasses import dataclass, asdict


@dataclass
class Song:
    id: int
    title: str
    artist: str
    year: int
    album: str | None = None
    image: str | None = None



    def __str__(self) -> str:
        return f"{self.title} | {self.album} | by {self.artist} [{self.year}] ({self.id})"

    def dict(self):
        """Convert the Song object to a dictionary."""
        return asdict(self)
