import Foundation
import Combine

class PhoneScoringViewModel: ObservableObject {

    // MARK: - Published state

    @Published var state: MatchState
    @Published var situation: GameSituation = .none
    @Published var selectedTag: PointTag = .normal
    @Published var selectedServeType: ServeType = .first
    @Published var serveSpeedKmh: Double? = nil
    @Published var isMatchOver: Bool = false

    // MARK: - Dependencies

    private var engine: TennisEngine
    private let repository: MatchRepository
    private let speaker: ScoreSpeaker
    private let watchSync: WatchSyncManager
    private let castManager: CastManager
    let voiceMode: VoiceCalloutMode

    // MARK: - Init from config (new match)

    init(
        config: MatchConfig,
        voiceMode: VoiceCalloutMode,
        repository: MatchRepository  = .shared,
        speaker: ScoreSpeaker        = .shared,
        watchSync: WatchSyncManager  = .shared,
        castManager: CastManager     = .shared
    ) {
        self.engine      = TennisEngine(config: config)
        self.state       = engine.state
        self.voiceMode   = voiceMode
        self.repository  = repository
        self.speaker     = speaker
        self.watchSync   = watchSync
        self.castManager = castManager

        refreshDerived()
    }

    // MARK: - Init from existing state (resume match)

    init(
        state: MatchState,
        voiceMode: VoiceCalloutMode,
        repository: MatchRepository  = .shared,
        speaker: ScoreSpeaker        = .shared,
        watchSync: WatchSyncManager  = .shared,
        castManager: CastManager     = .shared
    ) {
        self.engine      = TennisEngine(state: state)
        self.state       = state
        self.voiceMode   = voiceMode
        self.repository  = repository
        self.speaker     = speaker
        self.watchSync   = watchSync
        self.castManager = castManager

        refreshDerived()
    }

    // MARK: - Actions

    func awardPoint(to side: PlayerSide) {
        let previous = engine.state
        engine.awardPoint(
            to: side,
            tag: selectedTag,
            serveType: selectedServeType
        )
        afterStateChange(previous: previous)
    }

    func undo() {
        engine.undo()
        state     = engine.state
        situation = SituationDetector.detect(state)
        isMatchOver = (state.winner != nil)
        // Do not speak on undo — just refresh UI state silently.
        watchSync.sendMatchState(state)
        castManager.sendMatchState(state)
    }

    func endMatch() {
        let previous = engine.state
        engine.endMatchNow()
        afterStateChange(previous: previous)
    }

    // MARK: - Private

    private func refreshDerived() {
        situation   = SituationDetector.detect(state)
        isMatchOver = (state.winner != nil)
    }

    /// Called after every engine mutation that advances the match.
    private func afterStateChange(previous: MatchState) {
        let current = engine.state

        // 1. Update published properties.
        state     = current
        situation = SituationDetector.detect(current)
        isMatchOver = (current.winner != nil)

        // 2. Persist match state.
        repository.saveMatchState(current)

        // 3. Persist the point event that was just recorded, if any.
        if let lastEvent = current.pointHistory.last {
            repository.savePointEvent(lastEvent,
                                      serveType: selectedServeType,
                                      speedKmh: serveSpeedKmh)
        }

        // 4. Sync to watch.
        watchSync.sendMatchState(current)

        // 5. Cast to Chromecast (stub until CocoaPods wired up).
        castManager.sendMatchState(current)

        // 6. Speak the transition.
        speaker.speakTransition(previous: previous, current: current, mode: voiceMode)

        // 7. Reset per-point selections.
        selectedTag = .normal
        // Note: selectedServeType and serveSpeedKmh are intentionally preserved
        // between points so the scorer doesn't have to re-select them each time.
        // Reset serveSpeedKmh since speed is unique per serve.
        serveSpeedKmh = nil
    }
}
