import Foundation

/// What a card's QR code points to.
struct CardCode: Equatable {
    /// `nil`: an old TrackStar card without a dataset, played from the active one.
    var dataset: String?
    var number: Int

    /// - `trackstar://hitster/?id=12` (cards from `generate.py`)
    /// - `…?id=12` (cards from before the dataset was part of the code)
    /// - `www.hitstergame.com/de/00012` (original German Hitster cards; other editions have other songs)
    init?(_ string: String) {
        let string = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = string.firstMatch(of: #/hitstergame\.com/de/(\d+)/?$/#), let number = Int(match.1) {
            self.init(dataset: "hitster", number: number)
        } else if let components = URLComponents(string: string),
                  let number = components.queryItems?.first(where: { $0.name == "id" })?.value.flatMap(Int.init)
        {
            let host = components.scheme == "trackstar" ? components.host : nil
            self.init(dataset: host.flatMap { $0.isEmpty ? nil : $0 }, number: number)
        } else {
            return nil
        }
    }

    init(dataset: String?, number: Int) {
        self.dataset = dataset
        self.number = number
    }
}

#if DEBUG
    /// Runs once at launch in debug builds; there is no test target.
    func checkCardCodes() {
        assert(CardCode("trackstar://taylor-swift/?id=42") == CardCode(dataset: "taylor-swift", number: 42))
        assert(CardCode("http://www.hitstergame.com/de/00012") == CardCode(dataset: "hitster", number: 12))
        assert(CardCode("trackstar://?id=7") == CardCode(dataset: nil, number: 7))
        assert(CardCode("https://example.com/?id=3") == CardCode(dataset: nil, number: 3))
        assert(CardCode("www.hitstergame.com/en/00012") == nil)
        assert(CardCode("hello") == nil)
    }
#endif
