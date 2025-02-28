from abc import ABC, abstractmethod
from typing import List
from models.song import Song
from pathlib import Path

class BaseParser(ABC):
    def __init__(self, file_path: Path):
        """Initialize the parser and automatically load the JSON data."""
        self.file_path = file_path
        if not self.file_path.exists():
            raise FileNotFoundError(f"File {self.file_path} not found.")

    @abstractmethod
    def parse(self) -> List[Song]:
        """Subclasses must implement this method to parse the JSON data."""
        pass
