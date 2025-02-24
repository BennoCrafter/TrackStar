import argparse
import json
from pathlib import Path
from song import Song
from generate_song_card import generate_song_card
import time


def convert_songs_to_image_cards(songs: list[Song]):
    for song in songs:
        generate_song_card(song, output_path=Path("out"))

def main():
    parser = argparse.ArgumentParser(description="Process a file.")
    parser.add_argument("filepath", help="Path to the file", type=Path)

    args = parser.parse_args()

    filepath: Path = args.filepath

    if filepath.is_dir():
        print("Provided path is a directory. Invalid")
        return

    if not filepath.exists():
        print("The file does not exist.")
        return

    print(f"Filepath provided: {filepath}")

    try:
        with open(filepath, 'r') as file:
            data = json.load(file)

            songs = [Song(**item) for item in data]
            start_time = time.time()
            convert_songs_to_image_cards(songs)
            end_time = time.time()
            print(f"Generated {len(songs)} cards")
            print(f"Time taken: {end_time - start_time:.2f} seconds")
            print(f"Time taken per card: {(end_time - start_time) / len(songs):.4f} seconds")

    except Exception as e:
        print(f"Error reading or parsing the file: {e}")


if __name__ == "__main__":
    main()
