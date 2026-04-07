import Foundation
import SwiftUI
import Combine

class WatchMatchViewModel: ObservableObject {

    @Published var state: MatchState? = nil
    @Published var situation: GameSituation = .none
    @Published var canUndo: Bool = false
    @Published var showWalkout: Bool = false
    @Published var scoringOnPhone: Bool = false

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
        syncClient.onEndMatchReceived = { [weak self] in
            self?.handleRemoteEndMatch()
        }
        syncClient.onScoringModeReceived = { [weak self] mode in
            self?.scoringOnPhone = (mode == "phone")
        }
    }

    // MARK: - Config / State

    func applyNewConfig(_ config: MatchConfig) {
        let newEngine = TennisEngine(config: config)
        self.engine = newEngine
        self.state = newEngine.currentState
        self.situation = SituationDetector.detect(newEngine.currentState)
        self.canUndo = newEngine.canUndo
        self.showWalkout = (config.walkoutSongA != nil || config.walkoutSongB != nil)
        syncClient.lastAppliedPointNumber = 0
        syncClient.startResyncTimer()
    }

    func applyReceivedState(_ receivedState: MatchState) {
        let newEngine = TennisEngine(state: receivedState)
        self.engine = newEngine
        self.state = receivedState
        self.situation = SituationDetector.detect(receivedState)
        self.canUndo = newEngine.canUndo
        // If scoring has started on the phone, dismiss walkout screen
        if receivedState.pointNumber > 0 {
            self.showWalkout = false
        }
    }

    /// Phone told us to end the match — reset without sending back.
    private func handleRemoteEndMatch() {
        self.engine = nil
        self.state = nil
        self.situation = .none
        self.canUndo = false
        self.showWalkout = false
        self.scoringOnPhone = false
        syncClient.stopResyncTimer()
        syncClient.lastAppliedPointNumber = -1
    }

    // MARK: - Walkout

    func playWalkout(side: PlayerSide) {
        syncClient.sendPlayWalkout(side: side == .A ? "A" : "B")
    }

    func stopWalkout() {
        syncClient.sendStopWalkout()
    }

    func startMatch() {
        syncClient.sendStopWalkout()
        self.showWalkout = false
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
        self.situation = SituationDetector.detect(newState)
        self.canUndo = engine.canUndo
        syncClient.sendMatchState(newState)
    }

    func endMatchAndReset() {
        if let engine = engine {
            let finalState = engine.endMatchNow()
            syncClient.sendMatchState(finalState)
        }
        syncClient.sendEndMatch()
        syncClient.stopResyncTimer()
        syncClient.lastAppliedPointNumber = -1
        self.state = nil
        self.engine = nil
        self.situation = .none
        self.canUndo = false
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
        self.situation = SituationDetector.detect(newState)
        self.canUndo = engine.canUndo
        syncClient.sendMatchState(newState)
    }
}
