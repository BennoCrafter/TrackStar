from abc import ABC, abstractmethod
import json
from typing import List
from parsers.base_parser import BaseParser
from models.song import Song
from pathlib import Path

class BaseJSONParser(BaseParser):
    def __init__(self, file_path: Path):
        super().__init__(file_path)
        self.data = self._load_json()

    def _load_json(self):
        """Helper method to load JSON data from the file."""
        with open(self.file_path, 'r') as file:
            return json.load(file)

    @abstractmethod
    def parse(self) -> List[Song]:
        """Subclasses must implement this method to parse the JSON data."""
        pass
