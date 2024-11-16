import json
from collections import Counter
from chatgpted_data import *

# Define constants for file paths
ALL_SONGS_DB_URL = "/Users/benno/Downloads/all_songs_data/all_song_data.json"
SONGS_DB_URL = "/Users/benno/coding/swift/TrackStar/TrackStar/songs_table.json"

# Initialize data containers
cleaned_song_data = {}
years = []

# Function to load JSON data from a file
def load_json_data(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)

# Function to filter and transform song data into the desired format
def process_song_data(song_data):
    processed_data = []
    for song in song_data:
        # Filter out songs with Rank above 15
        if int(song.get("Rank", 0)) > 15:
            continue

        # Create a dictionary with selected fields
        u_song = {
            "artist": song.get("Artist"),
            "title": song.get("Song Title"),
            "album": song.get("Album"),
            "image": song.get("Album URL"),
            "year": song.get("Year")
        }
        processed_data.append(u_song)

    return processed_data

# Function to add songs data to the main collection
def add_data(songs_list):
    start_id = len(cleaned_song_data) + 1
    for i, song in enumerate(songs_list, start=start_id):
        cleaned_song_data[str(i)] = song
        years.append(song["year"])

# Function to save data to a JSON file
def save_to_json(file_path, data):
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)

# Main processing function
def main():
    # Step 1: Load the all songs data
    song_data = load_json_data(ALL_SONGS_DB_URL)
    print("Loaded song data!")

    # Process the song data (filtering and transforming)
    processed_song_data = process_song_data(song_data)

    # Add processed data to the cleaned song data
    add_data(processed_song_data)

    # Add data from additional sources (chatgpted data)
    add_data(top_songs_2020)
    add_data(top_songs_2021)
    add_data(top_songs_2022)

    # Display song count per year
    print(Counter(years))
    print(f"Total songs gathered: {sum(Counter(years).values())}")

    # Save the cleaned data to the target JSON file
    save_to_json(SONGS_DB_URL, cleaned_song_data)
    print(f"Saved data to: {SONGS_DB_URL}")

if __name__ == "__main__":
    main()
