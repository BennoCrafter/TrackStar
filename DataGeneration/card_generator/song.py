from pydantic import BaseModel
from typing import List

class Song(BaseModel):
    title: str
    artist: str
    album: str
    year: int
    image: str
    id: int
