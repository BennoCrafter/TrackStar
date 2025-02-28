from abc import ABC, abstractmethod
import csv
from typing import List
from pathlib import Path
from parsers.base_parser import BaseParser
from models.song import Song

class BaseCSVParser(BaseParser):
    def __init__(self, file_path: Path):
        super().__init__(file_path)
        self.data = self._load_csv()

    def _load_csv(self):
        """Helper method to load CSV data from the file."""
        with open(self.file_path, 'r', newline='') as file:
            reader = csv.DictReader(file)
            return list(reader)

    @abstractmethod
    def parse(self) -> List[Song]:
        """Subclasses must implement this method to parse the CSV data."""
        pass
