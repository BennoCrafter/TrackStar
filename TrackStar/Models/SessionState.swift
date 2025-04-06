final class SessionState {
    static let shared = SessionState()

    private init() {}

    var isFirstTimeDatasetsLoadingGlobalSource: Bool = true
}
