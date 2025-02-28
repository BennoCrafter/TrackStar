from models.data_handler import DataHandler
from parsers.json.taylor_swift_parser import TaylorSwiftParser
from parsers.json.general_parser import GeneralJSONParser
from parsers.csv.hitster_parser import HitsterCSVParser
import os
from pathlib import Path

os.makedirs("out", exist_ok=True)


ALL_SONGS_DB_URL = "/Users/benno/Downloads/all_songs_data/all_song_data.json"

# DataHandler.save_to_json("out/taylor_swift_songDB.json", TaylorSwiftParser(file_path=Path("resources/album-song-lyrics.json")).parse())
# DataHandler.save_to_json("out/general_songDB.json", GeneralJSONParser(file_path=Path(ALL_SONGS_DB_URL)).parse())
DataHandler.save_to_json("out/hitster_songDB.json", HitsterCSVParser(file_path=Path("/Users/benno/coding/TrackStar/backend/generation/music_db_generator/resources/hitster-de.csv")).parse())
