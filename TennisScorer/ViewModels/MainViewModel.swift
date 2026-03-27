import Foundation
import Combine

class MainViewModel: ObservableObject {

    // MARK: - Published state

    @Published var activeMatch: MatchState? = nil
    @Published var scoringViewModel: PhoneScoringViewModel? = nil

    // MARK: - Dependencies

    private let repository: MatchRepository
    private let settings: AppSettings
    private let watchSync: WatchSyncManager
    private let speaker: ScoreSpeaker

    // MARK: - Derived helpers

    var allMatches: [MatchState]       { repository.allMatches }
    var completedMatches: [MatchState] { allMatches.filter { $0.winner != nil } }
    var inProgressMatch: MatchState?   { allMatches.first { $0.winner == nil } }

    // MARK: - Init

    init(
        repository: MatchRepository = .shared,
        settings: AppSettings       = .shared,
        watchSync: WatchSyncManager = .shared,
        speaker: ScoreSpeaker       = .shared
    ) {
        self.repository = repository
        self.settings   = settings
        self.watchSync  = watchSync
        self.speaker    = speaker

        wireWatchCallbacks()
    }

    // MARK: - Public API

    /// Creates a new match and begins scoring.
    func startNewMatch(config: MatchConfig) {
        let vm = PhoneScoringViewModel(
            config: config,
            voiceMode: settings.voiceCalloutMode
        )
        scoringViewModel = vm
        activeMatch      = vm.state

        // Inform the watch about the new match configuration.
        watchSync.sendMatchConfig(config)
    }

    /// Resumes a match that was previously in progress.
    func resumeMatch(_ state: MatchState) {
        let vm = PhoneScoringViewModel(
            state: state,
            voiceMode: settings.voiceCalloutMode
        )
        scoringViewModel = vm
        activeMatch      = vm.state
    }

    /// Deletes a match from persistence and clears any active session if it matches.
    func deleteMatch(_ matchId: String) {
        repository.deleteMatch(matchId)

        if activeMatch?.matchId == matchId {
            activeMatch      = nil
            scoringViewModel = nil
        }
    }

    /// Ends the active match (e.g. via retire/walkover) and clears the scoring view.
    func endActiveMatch() {
        scoringViewModel?.endMatch()
        activeMatch      = scoringViewModel?.state
        scoringViewModel = nil
    }

    // MARK: - Private

    private func wireWatchCallbacks() {
        // Forward point events received from the watch to the active scoring VM.
        watchSync.onPointReceived = { [weak self] event in
            guard let self = self,
                  let vm = self.scoringViewModel,
                  vm.state.matchId == event.matchId
            else { return }

            // Translate the incoming PointEvent into an awardPoint call.
            vm.awardPoint(to: event.winner)
        }

        // Speak the full score when the watch requests it.
        watchSync.onSpeakScoreRequested = { [weak self] state in
            guard let self = self else { return }
            self.speaker.speakFullScore(state, mode: self.settings.voiceCalloutMode)
        }
    }
}
