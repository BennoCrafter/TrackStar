import json
from pathlib import Path
from models.song import Song

class DataHandler:
    def __init__(self) -> None:
        pass

    @staticmethod
    def save_to_json(file_path: Path | str, data: list[Song]):
        data_dict = [d.dict() for d in data]

        with open(file_path, 'w') as file:
            json.dump(data_dict, file, indent=4)
