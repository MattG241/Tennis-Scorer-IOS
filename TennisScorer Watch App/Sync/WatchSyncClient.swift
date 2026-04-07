import Foundation
import WatchConnectivity

class WatchSyncClient: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchSyncClient()

    @Published var isPhoneReachable: Bool = false

    var onConfigReceived: ((MatchConfig) -> Void)?
    var onStateReceived: ((MatchState) -> Void)?
    var onEndMatchReceived: (() -> Void)?
    var onScoringModeReceived: ((String) -> Void)?

    /// Tracks the highest pointNumber we've applied, to ignore stale state.
    var lastAppliedPointNumber: Int = -1

    /// Periodic timer that requests state from the phone every 30s.
    private var resyncTimer: Timer?

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else {
            print("[WatchSyncClient] WCSession NOT supported")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        print("[WatchSyncClient] WCSession activation requested")
    }

    // MARK: - Sending

    func sendMatchState(_ state: MatchState) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            print("[WatchSyncClient] sendMatchState: session not activated")
            return
        }
        guard let payload = encode(state) else {
            print("[WatchSyncClient] sendMatchState: failed to encode state")
            return
        }
        lastAppliedPointNumber = state.pointNumber
        let message: [String: Any] = ["type": "match_state", "payload": payload]
        if session.isReachable {
            print("[WatchSyncClient] Sending match_state to phone (reachable)")
            session.sendMessage(message, replyHandler: nil) { error in
                print("[WatchSyncClient] sendMatchState error: \(error) — retrying in 2s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    guard WCSession.default.isReachable else {
                        WCSession.default.transferUserInfo(message)
                        return
                    }
                    WCSession.default.sendMessage(message, replyHandler: nil) { retryError in
                        print("[WatchSyncClient] Retry also failed: \(retryError) — using transferUserInfo")
                        WCSession.default.transferUserInfo(message)
                    }
                }
            }
        } else {
            print("[WatchSyncClient] Sending match_state via transferUserInfo (not reachable)")
            session.transferUserInfo(message)
        }
    }

    func requestSpeakScore(state: MatchState) {
        guard WCSession.default.isReachable else { return }
        guard let payload = encode(state) else { return }
        let message: [String: Any] = ["type": "speak_score", "payload": payload]
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[WatchSyncClient] requestSpeakScore error: \(error)")
        })
    }

    /// Tells the phone to play a walkout song for the given side ("A" or "B").
    func sendPlayWalkout(side: String) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        let message: [String: Any] = ["type": "play_walkout", "payload": side]
        session.sendMessage(message, replyHandler: nil) { error in
            print("[WatchSyncClient] sendPlayWalkout error: \(error)")
        }
    }

    /// Tells the phone to stop any walkout song.
    func sendStopWalkout() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        let message: [String: Any] = ["type": "stop_walkout"]
        session.sendMessage(message, replyHandler: nil) { error in
            print("[WatchSyncClient] sendStopWalkout error: \(error)")
        }
    }

    /// Tells the phone that the watch has ended the match.
    func sendEndMatch() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let message: [String: Any] = ["type": "end_match"]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("[WatchSyncClient] sendEndMatch error: \(error)")
            }
        } else {
            session.transferUserInfo(message)
        }
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
        print("[WatchSyncClient] Activation complete — state: \(activationState.rawValue), reachable: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        if let error = error {
            print("[WatchSyncClient] Activation error: \(error)")
        }
        // Check for any pending application context from the phone
        if activationState == .activated {
            let ctx = session.receivedApplicationContext
            if !ctx.isEmpty {
                print("[WatchSyncClient] Found pending applicationContext: \(ctx.keys)")
                handleIncomingMessage(ctx)
            }
            // Ask the phone for current state
            requestStateSync()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[WatchSyncClient] Reachability changed — reachable: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        if session.isReachable {
            requestStateSync()
        }
    }

    // MARK: - Periodic resync

    /// Start a 30-second timer that requests state from the phone.
    func startResyncTimer() {
        stopResyncTimer()
        resyncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard WCSession.default.isReachable else { return }
            print("[WatchSyncClient] Periodic resync — requesting state from phone")
            self?.requestStateSync()
        }
    }

    /// Stop the periodic resync timer.
    func stopResyncTimer() {
        resyncTimer?.invalidate()
        resyncTimer = nil
    }

    /// Asks the phone to send its current match state/config.
    func requestStateSync() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let message: [String: Any] = ["type": "request_state"]
        if session.isReachable {
            print("[WatchSyncClient] Requesting state sync from phone")
            session.sendMessage(message, replyHandler: nil) { error in
                print("[WatchSyncClient] requestStateSync error: \(error)")
            }
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
        guard let type = message["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "end_match":
                self.onEndMatchReceived?()

            case "match_config":
                guard let payload = message["payload"] as? String,
                      let config = self.decode(MatchConfig.self, from: payload) else { return }
                self.onConfigReceived?(config)

            case "match_state":
                guard let payload = message["payload"] as? String,
                      let state = self.decode(MatchState.self, from: payload) else { return }
                // Dedup: only apply if the received state is at least as fresh as what we have.
                guard state.pointNumber >= self.lastAppliedPointNumber else {
                    print("[WatchSyncClient] Ignoring stale state (received point \(state.pointNumber), have \(self.lastAppliedPointNumber))")
                    return
                }
                self.lastAppliedPointNumber = state.pointNumber
                self.onStateReceived?(state)

            case "scoring_mode":
                let mode = message["payload"] as? String ?? "watch"
                self.onScoringModeReceived?(mode)

            default:
                print("[WatchSyncClient] Unhandled message type: \(type)")
            }
        }
    }
}
