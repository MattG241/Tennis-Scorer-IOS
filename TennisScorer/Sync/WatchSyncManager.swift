import Foundation
import WatchConnectivity
import Combine

class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    @Published var isWatchReachable: Bool = false

    /// Called on the main thread when the watch sends a point event.
    var onPointReceived: ((PointEvent) -> Void)?

    /// Called on the main thread when the watch requests a full score read-out.
    var onSpeakScoreRequested: ((MatchState) -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum MessageType: String {
        case matchConfig   = "match_config"
        case matchState    = "match_state"
        case pointEvent    = "point_event"
        case speakScore    = "speak_score"
    }

    private enum MessageKey {
        static let type    = "type"
        static let payload = "payload"
    }

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Sending to Watch

    func sendMatchConfig(_ config: MatchConfig) {
        send(type: .matchConfig, payload: config)
    }

    func sendMatchState(_ state: MatchState) {
        send(type: .matchState, payload: state)
    }

    func sendPointEvent(_ event: PointEvent) {
        send(type: .pointEvent, payload: event)
    }

    // MARK: - WCSessionDelegate — required

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            print("[WatchSyncManager] Activation error: \(error)")
        }
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = false
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = false
        }
        // Re-activate after deactivation (e.g. Apple Watch switch).
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    // MARK: - Receiving messages from watch

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
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

    // MARK: - Private helpers

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard
            let typeRaw  = message[MessageKey.type] as? String,
            let msgType  = MessageType(rawValue: typeRaw),
            let jsonStr  = message[MessageKey.payload] as? String,
            let jsonData = jsonStr.data(using: .utf8)
        else {
            print("[WatchSyncManager] Unrecognised message: \(message)")
            return
        }

        do {
            switch msgType {
            case .pointEvent:
                let event = try decoder.decode(PointEvent.self, from: jsonData)
                DispatchQueue.main.async { self.onPointReceived?(event) }

            case .speakScore:
                let state = try decoder.decode(MatchState.self, from: jsonData)
                DispatchQueue.main.async { self.onSpeakScoreRequested?(state) }

            case .matchConfig, .matchState:
                // Phone does not typically receive these from the watch,
                // but handle gracefully if the watch sends them.
                break
            }
        } catch {
            print("[WatchSyncManager] Failed to decode \(typeRaw): \(error)")
        }
    }

    private func send<T: Encodable>(type msgType: MessageType, payload: T) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        do {
            let data    = try encoder.encode(payload)
            let jsonStr = String(data: data, encoding: .utf8) ?? ""
            let message: [String: Any] = [
                MessageKey.type: msgType.rawValue,
                MessageKey.payload: jsonStr
            ]
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("[WatchSyncManager] sendMessage error: \(error)")
                }
            } else {
                // Fall back to application context for non-urgent state updates.
                try session.updateApplicationContext(message)
            }
        } catch {
            print("[WatchSyncManager] Failed to send \(msgType.rawValue): \(error)")
        }
    }
}
