import Foundation

class CastManager: NSObject, ObservableObject {
    static let shared = CastManager()

    @Published var isCasting: Bool = false
    @Published var isConnected: Bool = false

    private override init() {
        super.init()
    }

    static func configure() {
        // Chromecast disabled — will be re-enabled with updated GoogleCast SDK.
    }

    func sendMatchState(_ state: MatchState) {
        // No-op while Chromecast is disabled.
    }

    func disconnect() {
        // No-op while Chromecast is disabled.
    }
}
