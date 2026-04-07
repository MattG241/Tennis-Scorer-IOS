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
        // Wire the "New Match" button in the match-won overlay.
        vm.onRequestNewMatch = { [weak self] in
            self?.clearCompletedMatch()
        }
        scoringViewModel = vm
        activeMatch      = vm.state

        // Inform the watch about the new match configuration.
        watchSync.sendMatchConfig(config)
        watchSync.startResyncTimer()
    }

    /// Resumes a match that was previously in progress.
    func resumeMatch(_ state: MatchState) {
        let vm = PhoneScoringViewModel(
            state: state,
            voiceMode: settings.voiceCalloutMode
        )
        vm.onRequestNewMatch = { [weak self] in
            self?.clearCompletedMatch()
        }
        scoringViewModel = vm
        activeMatch      = vm.state
        watchSync.startResyncTimer()
    }

    /// Deletes a match from persistence and clears any active session if it matches.
    func deleteMatch(_ matchId: String) {
        repository.deleteMatch(matchId)

        if activeMatch?.matchId == matchId {
            activeMatch      = nil
            scoringViewModel = nil
            watchSync.sendEndMatch()
        }
    }

    /// Ends the active match (e.g. via retire/walkover) and clears the scoring view.
    func endActiveMatch() {
        scoringViewModel?.endMatch()
        activeMatch      = scoringViewModel?.state
        scoringViewModel = nil
        watchSync.sendEndMatch()
        watchSync.stopResyncTimer()
    }

    /// Convenience alias called from LiveView.
    func endMatch() {
        endActiveMatch()
    }

    /// Clears a match that has already ended through scoring (already saved).
    /// Does not call endMatch() again.
    func clearCompletedMatch() {
        activeMatch      = nil
        scoringViewModel = nil
        watchSync.stopResyncTimer()
        repository.loadAll()
    }

    // MARK: - Private

    private func wireWatchCallbacks() {
        // Apply authoritative match state received from the Watch.
        watchSync.onStateReceived = { [weak self] receivedState in
            guard let self = self else { return }

            // If we have an active scoring VM for this match, update it
            if let vm = self.scoringViewModel, vm.state.matchId == receivedState.matchId {
                vm.applyReceivedState(receivedState)
                self.activeMatch = receivedState
            } else {
                // Watch started or is scoring a match we don't have a VM for.
                // Create a scoring VM so the LiveView shows the match.
                self.resumeMatch(receivedState)
            }
        }

        // Speak the full score when the watch requests it.
        watchSync.onSpeakScoreRequested = { [weak self] state in
            guard let self = self else { return }
            self.speaker.speakFullScore(state, mode: self.settings.voiceCalloutMode)
        }

        // Watch ended its match — clear our active state
        watchSync.onEndMatchReceived = { [weak self] in
            guard let self = self else { return }
            self.scoringViewModel = nil
            self.activeMatch = nil
            self.watchSync.stopResyncTimer()
            self.repository.loadAll()
        }

        // Watch requested the current state — push it
        watchSync.onStateSyncRequested = { [weak self] in
            guard let self = self else { return }
            if let state = self.activeMatch {
                print("[MainViewModel] Pushing active match state to watch")
                self.watchSync.sendMatchConfig(state.config)
                self.watchSync.sendMatchState(state)
            } else {
                print("[MainViewModel] No active match to push to watch")
            }
        }

        // Watch wants to play a walkout song
        watchSync.onPlayWalkoutReceived = { [weak self] side in
            guard let self = self else { return }
            let config = self.scoringViewModel?.state.config ?? self.activeMatch?.config
            let song: String? = (side == "B") ? config?.walkoutSongB : config?.walkoutSongA
            if let song = song {
                print("[MainViewModel] Playing walkout song for side \(side): \(song)")
                WalkoutPlayer.shared.play(song)
            }
        }

        // Watch wants to stop walkout music
        watchSync.onStopWalkoutReceived = {
            print("[MainViewModel] Stopping walkout music (watch request)")
            WalkoutPlayer.shared.stop()
        }
    }
}
