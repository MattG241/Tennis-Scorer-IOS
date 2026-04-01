import Foundation
import Combine

class PhoneScoringViewModel: ObservableObject {

    // MARK: - Published state

    @Published var state: MatchState
    @Published var situation: GameSituation = .none
    @Published var selectedPointTag: PointTag = .normal
    @Published var selectedServeType: ServeType = .first
    @Published var lastServeSpeedKmh: Double? = nil
    @Published var isMatchOver: Bool = false
    @Published var matchDuration: String = "0:00"

    // MARK: - Computed convenience aliases (used by views)

    var matchState: MatchState { state }
    var canUndo: Bool { engine.canUndo }
    var gameSituation: GameSituation { situation }

    var currentPointScore: String {
        ScoreFormatter.displayPoints(state)
    }

    // MARK: - Callbacks

    /// Called when the user taps "New Match" on the match-won overlay.
    var onRequestNewMatch: (() -> Void)?

    // MARK: - Dependencies

    private var engine: TennisEngine
    private let repository: MatchRepository
    private let speaker: ScoreSpeaker
    private let watchSync: WatchSyncManager
    private let castManager: CastManager
    let voiceMode: VoiceCalloutMode

    // MARK: - Timer

    private var timerCancellable: AnyCancellable?

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
        startTimer()
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
        startTimer()
    }

    // MARK: - Actions

    func awardPoint(to side: PlayerSide) {
        let previous = engine.state
        let event = engine.awardPoint(to: side, tag: selectedPointTag)
        afterStateChange(previous: previous, event: event)
    }

    func undoLastPoint() {
        engine.undo()
        state       = engine.state
        situation   = SituationDetector.detect(state)
        isMatchOver = (state.winner != nil)
        watchSync.sendMatchState(state)
        castManager.sendMatchState(state)
    }

    func endMatch() {
        let previous = engine.state
        engine.endMatchNow()
        afterStateChange(previous: previous, event: nil)
    }

    /// Apply a state received from the Watch without re-scoring or echoing back.
    func applyReceivedState(_ newState: MatchState) {
        let previous = state
        engine      = TennisEngine(state: newState)
        state       = newState
        situation   = SituationDetector.detect(newState)
        isMatchOver = (newState.winner != nil)
        repository.saveMatchState(newState)
        // Speak the score change from the watch
        speaker.speakTransition(previous: previous, current: newState, mode: voiceMode)
    }

    func speakScore() {
        speaker.speakFullScore(state, mode: voiceMode)
    }

    func requestNewMatch() {
        onRequestNewMatch?()
    }

    // MARK: - Private

    private func refreshDerived() {
        situation   = SituationDetector.detect(state)
        isMatchOver = (state.winner != nil)
        updateDuration()
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateDuration() }
    }

    private func updateDuration() {
        let startMs  = state.startedAtMs
        let nowMs    = Int64(Date().timeIntervalSince1970 * 1000)
        let elapsed  = max(0, Int((nowMs - startMs) / 1000))
        let minutes  = elapsed / 60
        let seconds  = elapsed % 60
        matchDuration = String(format: "%d:%02d", minutes, seconds)
    }

    /// Called after every engine mutation that advances the match.
    private func afterStateChange(previous: MatchState, event: PointEvent?) {
        let current = engine.state

        // 1. Update published properties.
        state       = current
        situation   = SituationDetector.detect(current)
        isMatchOver = (current.winner != nil)

        // 2. Persist match state.
        repository.saveMatchState(current)

        // 3. Persist the point event, if one was generated.
        if let event = event {
            repository.savePointEvent(event,
                                      serveType: selectedServeType,
                                      speedKmh: lastServeSpeedKmh)
        }

        // 4. Sync to watch.
        watchSync.sendMatchState(current)

        // 5. Cast (stub until CocoaPods wired up).
        castManager.sendMatchState(current)

        // 6. Speak the transition.
        speaker.speakTransition(previous: previous, current: current, mode: voiceMode)

        // 7. Reset per-point selections; keep last speed as a starting reference.
        selectedPointTag  = .normal
        selectedServeType = .first
    }
}
