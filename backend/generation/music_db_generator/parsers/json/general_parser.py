from parsers.json.base_parser import BaseJSONParser
from resources.chatgpted_data import top_songs_2020_to_2022
from models.song import Song
from typing import List

class GeneralJSONParser(BaseJSONParser):
    def __init__(self, file_path: str):
        super().__init__(file_path)
        self.release_year_dict = {(1956, 1971): 2, (1971, 2019): 15, (2019, 2024): 18}

    def parse(self) -> List[Song]:
        songs = []

        i = 1
        for song in self.data:
            # Filter out songs with Rank above 15
            if int(song.get("Rank", 0)) > self.get_max_rank_for_year(int(song.get("Year"))):
                continue

            # Create a dictionary with selected fields
            u_song: Song = Song(
                artist=song.get("Artist"),
                title = song.get("Song Title"),
                album = song.get("Album"),
                image = song.get("Album URL"),
                year = int(song.get("Year")),
                id = i
            )

            songs.append(u_song)
            i += 1

        songs += self.add_manual_data(start_id=i+1)

        return songs


    def get_max_rank_for_year(self, year: int) -> int:
        for (start, end), max_rank in self.release_year_dict.items():
            if start <= year < end:
                return max_rank

        return 0

    def add_manual_data(self, start_id: int) -> List[Song]:
        sngs = []
        i = start_id
        for s in top_songs_2020_to_2022:
            sngs.append(
                Song(
                    artist= s.get("artist", ""),
                    title = s.get("title", ""),
                    album = s.get("album", ""),
                    image = s.get("image", ""),
                    year = int(s.get("year", "")),
                    id = i
                )
            )
            i += 1
        return sngs
