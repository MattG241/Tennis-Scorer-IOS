import Foundation
import SwiftUI
import Combine

class WatchMatchViewModel: ObservableObject {

    @Published var state: MatchState? = nil
    @Published var situation: GameSituation = .none

    private var engine: TennisEngine? = nil
    private let syncClient: WatchSyncClient

    init(syncClient: WatchSyncClient = .shared) {
        self.syncClient = syncClient

        syncClient.onConfigReceived = { [weak self] config in
            self?.applyNewConfig(config)
        }
        syncClient.onStateReceived = { [weak self] receivedState in
            self?.applyReceivedState(receivedState)
        }
    }

    // MARK: - Config / State

    func applyNewConfig(_ config: MatchConfig) {
        let newEngine = TennisEngine(config: config)
        self.engine = newEngine
        self.state = newEngine.currentState
        self.situation = SituationDetector.detect(state: newEngine.currentState)

        // Inform the phone of the new config
        if let payload = encode(config) {
            let message: [String: Any] = ["type": "match_config", "payload": payload]
            sendApplicationContext(message)
        }
    }

    func applyReceivedState(_ receivedState: MatchState) {
        // Recreate engine from received state so local scoring stays in sync
        let newEngine = TennisEngine(config: receivedState.config)
        newEngine.restoreState(receivedState)
        self.engine = newEngine
        self.state = receivedState
        self.situation = SituationDetector.detect(state: receivedState)
    }

    // MARK: - Scoring actions

    func pointA() {
        guard let engine = engine else { return }
        let event = engine.awardPoint(to: .A)
        afterPoint(event)
    }

    func pointB() {
        guard let engine = engine else { return }
        let event = engine.awardPoint(to: .B)
        afterPoint(event)
    }

    func undo() {
        guard let engine = engine else { return }
        engine.undo()
        let newState = engine.currentState
        self.state = newState
        self.situation = SituationDetector.detect(state: newState)
        syncClient.sendMatchState(newState)
    }

    func endMatchAndReset() {
        if let engine = engine {
            let finalState = engine.endMatchNow()
            syncClient.sendMatchState(finalState)
        }
        self.state = nil
        self.engine = nil
        self.situation = .none
    }

    func speakScoreNow() {
        guard let state = state else { return }
        syncClient.requestSpeakScore(state: state)
    }

    // MARK: - Private

    private func afterPoint(_ event: PointEvent) {
        guard let engine = engine else { return }
        let newState = engine.currentState
        self.state = newState
        self.situation = SituationDetector.detect(state: newState)
        syncClient.sendMatchState(newState)
        syncClient.sendPointEvent(event)
    }

    private func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func sendApplicationContext(_ context: [String: Any]) {
        // Application context is used for non-urgent state sharing
        // when the phone may not be immediately reachable
        DispatchQueue.global(qos: .background).async {
            // No-op placeholder: phone-initiated configs are handled
            // via WatchSyncClient messages; this is just for future use.
        }
    }
}
