import Foundation
import WatchConnectivity

class WatchSyncClient: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchSyncClient()

    @Published var isPhoneReachable: Bool = false

    var onConfigReceived: ((MatchConfig) -> Void)?
    var onStateReceived: ((MatchState) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Sending

    func sendMatchState(_ state: MatchState) {
        guard WCSession.default.isReachable else { return }
        guard let payload = encode(state) else { return }
        let message: [String: Any] = ["type": "match_state", "payload": payload]
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSyncClient] sendMatchState error: \(error)")
        })
    }

    func sendPointEvent(_ event: PointEvent) {
        guard WCSession.default.isReachable else { return }
        guard let payload = encode(event) else { return }
        let message: [String: Any] = ["type": "point_event", "payload": payload]
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSyncClient] sendPointEvent error: \(error)")
        })
    }

    func requestSpeakScore(state: MatchState) {
        guard WCSession.default.isReachable else { return }
        guard let payload = encode(state) else { return }
        let message: [String: Any] = ["type": "speak_score", "payload": payload]
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSyncClient] requestSpeakScore error: \(error)")
        })
    }

    // MARK: - Encoding helpers

    private func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        if let error = error {
            print("[WatchSyncClient] Activation error: \(error)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler(["status": "ok"])
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingMessage(applicationContext)
    }

    // MARK: - Message routing

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard
            let type = message["type"] as? String,
            let payload = message["payload"] as? String
        else { return }

        DispatchQueue.main.async {
            switch type {
            case "match_config":
                if let config = self.decode(MatchConfig.self, from: payload) {
                    self.onConfigReceived?(config)
                }
            case "match_state":
                if let state = self.decode(MatchState.self, from: payload) {
                    self.onStateReceived?(state)
                }
            default:
                print("[WatchSyncClient] Unhandled message type: \(type)")
            }
        }
    }
}
