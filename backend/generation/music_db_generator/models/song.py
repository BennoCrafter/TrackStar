
class Song:
    def __init__(self, title: str, artist: str, album: str, year: int, image: str, id: int) -> None:
        self.title = title
        self.artist = artist
        self.album = album
        self.year = year
        self.image = image
        self.id = id

    def __str__(self) -> str:
        return f"{self.title} | {self.album} | by {self.artist} [{self.year}] ({self.id})"

    def dict(self):
        """Convert the Song object to a dictionary."""
        return {
            "title": self.title,
            "artist": self.artist,
            "album": self.album,
            "year": self.year,
            "image": self.image,
            "id": self.id
        }
