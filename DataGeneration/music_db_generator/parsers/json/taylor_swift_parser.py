from parsers.json.base_parser import BaseJSONParser
from models.song import Song
import abc
from typing import List

class TaylorSwiftParser(BaseJSONParser):
    def parse(self) -> List[Song]:
        songs = []

        i = 1
        for era in self.data:
            if era.get("Code") in ["OTH"]:
                continue

            year = era.get("Year")
            album_title = era.get("Title")

            for song in era.get("Songs"):
                u_song: Song = Song(
                    title=song.get("Title"),
                    artist="Taylor Swift",
                    album=album_title,
                    year=year,
                    image="",
                    id=i
                    )

                songs.append(u_song)
                i += 1

        return songs
