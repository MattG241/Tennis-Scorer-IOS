import Foundation
import WatchConnectivity
import Combine

class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    @Published var isWatchReachable: Bool = false

    /// Called on the main thread when the watch sends its authoritative match state.
    var onStateReceived: ((MatchState) -> Void)?

    /// Called on the main thread when the watch requests a full score read-out.
    var onSpeakScoreRequested: ((MatchState) -> Void)?

    /// Called on the main thread when the watch signals the match has ended.
    var onEndMatchReceived: (() -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Called on the main thread when the watch requests the current match state.
    var onStateSyncRequested: (() -> Void)?

    /// Called on the main thread when the watch wants to play a walkout song ("A" or "B").
    var onPlayWalkoutReceived: ((String) -> Void)?

    /// Called on the main thread when the watch wants to stop walkout music.
    var onStopWalkoutReceived: (() -> Void)?

    private enum MessageType: String {
        case matchConfig   = "match_config"
        case matchState    = "match_state"
        case speakScore    = "speak_score"
        case endMatch      = "end_match"
        case requestState  = "request_state"
        case playWalkout   = "play_walkout"
        case stopWalkout   = "stop_walkout"
        case scoringMode   = "scoring_mode"
    }

    private enum MessageKey {
        static let type    = "type"
        static let payload = "payload"
    }

    /// Periodic timer that pushes state to the watch every 30s while a match is active.
    private var resyncTimer: Timer?

    /// Last state sent — retained for retry and periodic push.
    private var lastSentState: MatchState?

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else {
            print("[WatchSyncManager] WCSession NOT supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        print("[WatchSyncManager] WCSession activation requested")
    }

    // MARK: - Sending to Watch

    func sendMatchConfig(_ config: MatchConfig) {
        send(type: .matchConfig, payload: config)
    }

    func sendMatchState(_ state: MatchState) {
        lastSentState = state
        send(type: .matchState, payload: state)
    }

    // MARK: - Periodic resync

    /// Start a 30-second timer that pushes the latest state to the watch.
    /// Call when a match becomes active.
    func startResyncTimer() {
        stopResyncTimer()
        resyncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self,
                  let state = self.lastSentState,
                  WCSession.default.isReachable else { return }
            print("[WatchSyncManager] Periodic resync — pushing state to watch")
            self.send(type: .matchState, payload: state)
        }
    }

    /// Stop the periodic resync timer.
    func stopResyncTimer() {
        resyncTimer?.invalidate()
        resyncTimer = nil
    }

    /// Tells the watch which device is scoring: "phone" or "watch".
    func sendScoringMode(_ mode: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let message: [String: Any] = [
            MessageKey.type: MessageType.scoringMode.rawValue,
            MessageKey.payload: mode
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("[WatchSyncManager] sendScoringMode error: \(error)")
            }
        } else {
            try? session.updateApplicationContext(message)
        }
    }

    /// Tells the watch to end its current match.
    func sendEndMatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let message: [String: Any] = [MessageKey.type: MessageType.endMatch.rawValue]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("[WatchSyncManager] sendEndMatch error: \(error)")
            }
        } else {
            try? session.updateApplicationContext(message)
        }
    }

    // MARK: - WCSessionDelegate — required

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            print("[WatchSyncManager] Activation error: \(error)")
        }
        print("[WatchSyncManager] Activation complete — state: \(activationState.rawValue), paired: \(session.isPaired), appInstalled: \(session.isWatchAppInstalled), reachable: \(session.isReachable)")
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
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[WatchSyncManager] Reachability changed — reachable: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            if session.isReachable {
                self.onStateSyncRequested?()
            }
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

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }

    // MARK: - Private helpers

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard
            let typeRaw = message[MessageKey.type] as? String,
            let msgType = MessageType(rawValue: typeRaw)
        else {
            print("[WatchSyncManager] Unrecognised message: \(message)")
            return
        }
        print("[WatchSyncManager] Received message type: \(typeRaw)")

        // No-payload messages
        if msgType == .endMatch {
            DispatchQueue.main.async { self.onEndMatchReceived?() }
            return
        }
        if msgType == .requestState {
            print("[WatchSyncManager] Watch requested state sync")
            DispatchQueue.main.async { self.onStateSyncRequested?() }
            return
        }
        if msgType == .stopWalkout {
            print("[WatchSyncManager] Watch requested stop walkout")
            DispatchQueue.main.async { self.onStopWalkoutReceived?() }
            return
        }
        if msgType == .playWalkout {
            let side = message[MessageKey.payload] as? String ?? "A"
            print("[WatchSyncManager] Watch requested play walkout side: \(side)")
            DispatchQueue.main.async { self.onPlayWalkoutReceived?(side) }
            return
        }

        guard
            let jsonStr  = message[MessageKey.payload] as? String,
            let jsonData = jsonStr.data(using: .utf8)
        else {
            print("[WatchSyncManager] Missing payload for \(typeRaw)")
            return
        }

        do {
            switch msgType {
            case .speakScore:
                let state = try decoder.decode(MatchState.self, from: jsonData)
                DispatchQueue.main.async { self.onSpeakScoreRequested?(state) }

            case .matchState:
                let receivedState = try decoder.decode(MatchState.self, from: jsonData)
                DispatchQueue.main.async { self.onStateReceived?(receivedState) }

            case .matchConfig, .endMatch, .requestState, .playWalkout, .stopWalkout, .scoringMode:
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
                session.sendMessage(message, replyHandler: nil) { [weak self] error in
                    print("[WatchSyncManager] sendMessage error: \(error) — retrying in 2s")
                    // Retry once after 2 seconds; fall back to applicationContext if that fails too.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        guard WCSession.default.isReachable else {
                            try? WCSession.default.updateApplicationContext(message)
                            return
                        }
                        WCSession.default.sendMessage(message, replyHandler: nil) { retryError in
                            print("[WatchSyncManager] Retry also failed: \(retryError) — falling back to applicationContext")
                            try? WCSession.default.updateApplicationContext(message)
                        }
                    }
                }
            } else {
                try session.updateApplicationContext(message)
            }
        } catch {
            print("[WatchSyncManager] Failed to send \(msgType.rawValue): \(error)")
        }
    }
}
