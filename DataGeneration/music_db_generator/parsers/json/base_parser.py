from abc import ABC, abstractmethod
import json
from typing import List
from models.song import Song

class BaseJSONParser(ABC):
    def __init__(self, file_path: str):
        """Initialize the parser and automatically load the JSON data."""
        self.file_path = file_path
        self.data = self._load_json()

    def _load_json(self):
        """Helper method to load JSON data from the file."""
        with open(self.file_path, 'r') as file:
            return json.load(file)

    @abstractmethod
    def parse(self) -> List[Song]:
        """Subclasses must implement this method to parse the JSON data."""
        pass
