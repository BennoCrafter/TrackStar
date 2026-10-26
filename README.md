<p align="center">
  <img src="assets/icons/RoundedIcon.png" width="150" height="150" alt="TrackStar icon">
</p>

<div align="center">
    <h1>TrackStar</h1>
  
  **An open-source game inspired by Hitster, where players guess the release year of songs to build a chronological timeline. 🎶**

  
   [![Stars](https://img.shields.io/github/stars/BennoCrafter/TrackStar?style=social)](https://github.com/BennoCrafter/TrackStar)
   [![Forks](https://img.shields.io/github/forks/BennoCrafter/TrackStar?style=social)](https://github.com/BennoCrafter/TrackStar)
   [![Open Issues](https://img.shields.io/github/issues/BennoCrafter/TrackStar)](https://github.com/BennoCrafter/TrackStar/issues)
   [![Last Updated](https://img.shields.io/github/last-commit/BennoCrafter/TrackStar)](https://github.com/BennoCrafter/TrackStar/commits/main)
   [![Discord](https://img.shields.io/discord/1363885525991165984)](https://discord.gg/JNu7qXGpzV)
</div>


## Preview ⭐️
| Front cards | Back cards | Gameplay |
|------------|------------|----------|
| <img src="assets/screenshots/dataset/qr_codes.png" width="250"> | <img src="assets/screenshots/dataset/song_cards.png" width="250"> | <img src="assets/screenshots/gameplay.png" width="250"> |

## Key Features 🚀

*   **Gameplay:** Guess the release year of songs and create a chronological timeline.
*   **Open-Source:**  Contribute to the project and help expand its features.
*   **Custom Datasets:** Create your own song datasets using the provided `generate.py` backend script.
*   **Apple Music Integration:** Play the songs using Apple Music.
*   **Hitster cards support:** Choose between your own printed cards or use the original Hitster card set.

## Creating Custom Datasets

TrackStar allows you to use custom song datasets. A Python script, `generate.py` in the `backend` directory, is provided to help you generate these datasets.

```bash
cd backend
pip install -r requirements.txt

# optional: turn a raw source into a songs.json with a parser script (see parsers/)
python parsers/hitster_csv.py -o songs.json

# build datasets/<name>/ with info.json, songs.json, README.md and a printable cards.pdf
python generate.py build songs.json --name my-songs --display-name "My Songs"
```

`songs.json` is a list of `{"id", "title", "artist", "year"?, "album"?}` objects. `cards.pdf` prints duplex (flip on long edge): QR fronts, song backs colored per 5-year period. See [backend/README.md](backend/README.md) for how it works.

If you've created a custom dataset that you think would be valuable for other players, consider contributing it to the official repository:

- Create a pull request with:
   - A clear description of your dataset (genre, time period, theme etc.)
   - Any special notes about the dataset


## Installation 💻

### Prerequisites

*   Xcode (latest version recommended)
*   Swift (6.0 or higher)
*   A macOS environment for development

### Steps

1.  Clone the repository:

    ```bash
    git clone https://github.com/BennoCrafter/TrackStar.git
    cd TrackStar
    ```

2.  Open the project in Xcode:

    ```bash
    open TrackStar.xcodeproj
    ```

3.  Build and run the project on your desired device.

## Contributing 🤝

This project is open to contributions.

## License 📝

This project is licensed under the Mozilla Public License 2.0 - see the [LICENSE](LICENSE) file for details.
