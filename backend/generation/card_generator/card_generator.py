import argparse
import json
from pathlib import Path
from generation.models.song import Song
import time
from tqdm import tqdm
from generation.card_generator.generate_song_card import generate_song_card

def convert_songs_to_image_cards(songs: list[Song], output_path: Path):
    for song in tqdm(songs, desc="Generating song cards", unit="card"):
        generate_song_card(song, output_path=output_path)

def main():
    parser = argparse.ArgumentParser(description="Process a file.")
    parser.add_argument("music_db_path", help="Path to the music database file", type=Path)
    parser.add_argument("-o", "--output", help="Output directory", type=Path, default=Path("out/song_cards"))

    args = parser.parse_args()

    music_db_path: Path = args.music_db_path
    output_path: Path = args.output
    output_path.mkdir(parents=True, exist_ok=True)

    if music_db_path.is_dir():
        print("Provided path is a directory. Invalid")
        return

    if not music_db_path.exists():
        print("The file does not exist.")
        return

    print(f"Music database path provided: {music_db_path}")

    try:
        with open(music_db_path, 'r') as file:
            data = json.load(file)

            songs = [Song(**item) for item in data]
            start_time = time.time()
            convert_songs_to_image_cards(songs, output_path)
            end_time = time.time()
            print(f"Generated {len(songs)} cards")
            print(f"Time taken: {end_time - start_time:.2f} seconds")
            print(f"Time taken per card: {(end_time - start_time) / len(songs):.4f} seconds")

    except Exception as e:
        print(f"Error reading or parsing the file: {e}")


if __name__ == "__main__":
    main()
