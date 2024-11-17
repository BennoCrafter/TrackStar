import json
from os import confstr

tsw_abbreviations = {
    "TSW": "Taylor Swift (aka Debut)",
    "FER": "Fearless",
    "SPN": "Speak Now",
    "RED": "Red",
    "NEN": "1989",
    "REP": "Reputation",
    "LVR": "Lover",
    "FOL": "Folklore",
    "EVE": "Evermore",
    "MID": "Midnights",
    "TPD": "The Tortured Poets Department",
    "OTH": "Other Songs"
}

ignored_tsw = ["OTH"]

def load_json_data(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)

def save_to_json(file_path, data):
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)

def process():
    d = load_json_data("album-song-lyrics.json")
    data = []
    i = 1
    for era in d:
        if era.get("Code") in ignored_tsw:
            continue

        year = era.get("Year")
        album_title = era.get("Title")

        for song in era.get("Songs"):
            u_song = {
                "artist": "Taylor Swift",
                "title": song.get("Title"),
                "album": album_title,
                "image": "",
                "year": year,
                "id": i
            }
            data.append(u_song)
            i += 1

    return data

save_to_json("taylorSwiftSongDB.json", process())
