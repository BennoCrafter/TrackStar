from parsers.csv.base_parser import BaseCSVParser
from typing import List
from models.song import Song

class HitsterCSVParser(BaseCSVParser):
    def __init__(self, file_path):
        super().__init__(file_path)

    def parse(self) -> List[Song]:
        songs = []
        for row in self.data:
            card_id = row.get("Card#")
            title = row.get("Title")
            artist = row.get("Artist")
            year = row.get("Year")

            if card_id is None or title is None or artist is None or year is None:
                print(f"Skipping row: {row}")
                continue

            songs.append(Song(id=int(card_id), title=title, artist=artist, year=int(year)))
        return songs
