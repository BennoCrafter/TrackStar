# TrackStar

Hitster-inspired open-source game, where players guess the release year of songs to create a chronological timeline.


## Backend

cwd: `backend`

### Generation scripts

-   `python generation/pdf_generator/main.py cards.pdf out/qr_codes out/song_cards 1 8`
-   `python generation/card_generator/card_generator.py out/hitster_songDB.json`
-   `python generation/qr_code_generator/code_generation.py`
