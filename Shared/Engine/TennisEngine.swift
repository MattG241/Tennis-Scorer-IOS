// TennisEngine.swift
// TennisScorer – Shared
//
// Central scoring engine. All tennis rule logic lives here.
// This is a plain class (not an actor) so it can be used synchronously
// from both the iOS app and the Watch extension. Callers that need
// thread-safety must serialise access themselves (e.g. via @MainActor
// view models or a serial DispatchQueue).

import Foundation

// MARK: - TennisEngine

final class TennisEngine {

    // MARK: State

    /// The current, authoritative match state.
    private(set) var state: MatchState

    /// Convenience alias used by Watch and other callers.
    var currentState: MatchState { state }

    /// `true` when there is at least one state on the undo stack.
    var canUndo: Bool { !history.isEmpty }

    /// A stack of previous states enabling unlimited undo.
    private var history: [MatchState] = []

    // MARK: Init

    /// Creates a fresh engine from a `MatchConfig`.
    init(config: MatchConfig) {
        self.state = MatchState(config: config)
    }

    /// Restores an engine from a previously-persisted `MatchState`
    /// (e.g. when reopening the app mid-match).
    init(state: MatchState) {
        self.state = state
    }

    /// Replaces the engine's current state with `newState` and clears the undo history.
    /// Use this when syncing an authoritative state from the phone to the watch.
    func restoreState(_ newState: MatchState) {
        history.removeAll()
        state = newState
    }

    // MARK: - Public API

    /// Awards a point to `side`, optionally tagged for statistics.
    ///
    /// - Returns: The `PointEvent` that was generated (discardable).
    @discardableResult
    func awardPoint(to side: PlayerSide, tag: PointTag = .normal) -> PointEvent {
        // 1. Snapshot current state so we can undo.
        history.append(state)

        // 2. Build the point event.
        let event = PointEvent(
            matchId:     state.matchId,
            pointNumber: state.pointNumber + 1,
            winner:      side,
            tag:         tag,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        )

        // 3. Advance point counter and raw game score.
        state.pointNumber += 1
        if side == .A {
            state.currentGame.rawA += 1
        } else {
            state.currentGame.rawB += 1
        }

        // 4. Check for game completion.
        if isGameWon(game: state.currentGame, format: state.config.format) {
            let gameWinner = gameWinner(game: state.currentGame)

            // --- TIEBREAK_ONLY: match ends immediately on game win ---
            if state.config.format == .tiebreakOnly {
                state.winner    = gameWinner
                state.endedAtMs = event.timestampMs
                return event
            }

            // Increment set-games for the game winner.
            if gameWinner == .A {
                state.currentGamesA += 1
            } else {
                state.currentGamesB += 1
            }

            // 5. Check for set completion.
            if isSetWon(gamesA: state.currentGamesA, gamesB: state.currentGamesB,
                        format: state.config.format) {
                // Record the set.
                state.completedSets.append(
                    SetScore(gamesA: state.currentGamesA, gamesB: state.currentGamesB)
                )
                state.currentGamesA = 0
                state.currentGamesB = 0

                // 6. Check for match completion.
                if isMatchWon(sets: state.completedSets, format: state.config.format) {
                    state.winner    = setWinner(sets: state.completedSets)
                    state.endedAtMs = event.timestampMs
                    // Don't reset the game – leave scoreboard intact.
                    return event
                }
            }

            // Match continues – advance server and reset the game.
            advanceServer()
            let startTiebreak = shouldStartTiebreak(
                gamesA: state.currentGamesA,
                gamesB: state.currentGamesB,
                format: state.config.format
            )
            state.currentGame = GamePoints(tiebreak: startTiebreak)
        }

        return event
    }

    /// Reverts to the state before the most recent `awardPoint` call.
    ///
    /// - Returns: `false` if there is nothing to undo.
    @discardableResult
    func undo() -> Bool {
        guard let previous = history.popLast() else { return false }
        state = previous
        return true
    }

    /// Immediately ends the match, determining the winner from the
    /// current score. Useful for "retire" / concede scenarios.
    /// Returns the final `MatchState` for callers that need it.
    @discardableResult
    func endMatchNow() -> MatchState {
        // Save so the caller can undo even an explicit end.
        history.append(state)

        state.endedAtMs = Int64(Date().timeIntervalSince1970 * 1000)

        // Determine winner by counting completed sets.
        var setsA = 0
        var setsB = 0
        for set in state.completedSets {
            if set.gamesA > set.gamesB { setsA += 1 } else { setsB += 1 }
        }

        if setsA > setsB {
            state.winner = .A
        } else if setsB > setsA {
            state.winner = .B
        } else {
            // Sets are tied – use current set games.
            if state.currentGamesA > state.currentGamesB {
                state.winner = .A
            } else if state.currentGamesB > state.currentGamesA {
                state.winner = .B
            } else {
                // Everything is tied – default to side A.
                state.winner = .A
            }
        }
        return state
    }

    // MARK: - Private Scoring Helpers

    /// Returns `true` when the game described by `game` has been won.
    private func isGameWon(game: GamePoints, format: MatchFormat) -> Bool {
        let a = game.rawA
        let b = game.rawB
        let maxPts = max(a, b)
        let diff   = abs(a - b)

        if game.tiebreak {
            // First to 7, win by 2.
            return maxPts >= 7 && diff >= 2
        }

        switch format {
        case .noAd:
            // No-Ad: first to 4 points wins. At 3-3 (deuce) the *next* point wins,
            // so the game is won when either side reaches 4 raw points.
            // (3-3 alone must NOT trigger a win — the winning point must be played.)
            return maxPts >= 4
        default:
            // Standard: first to 4, win by 2 (deuce).
            return maxPts >= 4 && diff >= 2
        }
    }

    /// Returns the side that won the game. Only call when `isGameWon` is true.
    private func gameWinner(game: GamePoints) -> PlayerSide {
        return game.rawA > game.rawB ? .A : .B
    }

    /// Returns `true` when the set described by the current game counts has been won.
    private func isSetWon(gamesA: Int, gamesB: Int, format: MatchFormat) -> Bool {
        let maxG = max(gamesA, gamesB)
        let minG = min(gamesA, gamesB)
        let diff = maxG - minG

        switch format {
        case .shortSets:
            // First to 4 games, win by 2; tiebreak at 3-3 (so 4-3 is valid).
            return (maxG >= 4 && diff >= 2) || (maxG == 4 && minG == 3)
        default:
            // Standard: first to 6, win by 2; 7-5 or 7-6 (tiebreak) are valid.
            return (maxG >= 6 && diff >= 2) || (maxG == 7 && minG <= 6)
        }
    }

    /// Returns the side that has won more sets. Call only when a new set has just been appended.
    private func setWinner(sets: [SetScore]) -> PlayerSide {
        var a = 0, b = 0
        for s in sets {
            if s.gamesA > s.gamesB { a += 1 } else { b += 1 }
        }
        return a > b ? .A : .B
    }

    /// Returns `true` when the completed-sets array indicates the match has been won.
    private func isMatchWon(sets: [SetScore], format: MatchFormat) -> Bool {
        var a = 0, b = 0
        for s in sets {
            if s.gamesA > s.gamesB { a += 1 } else { b += 1 }
        }
        let target = (format == .bestOf5) ? 3 : 2
        return a >= target || b >= target
    }

    /// Returns `true` when the next game should be played as a tiebreak.
    private func shouldStartTiebreak(gamesA: Int, gamesB: Int, format: MatchFormat) -> Bool {
        switch format {
        case .tiebreakOnly:
            // Handled in MatchState init; shouldn't reach here.
            return true
        case .shortSets:
            return gamesA == 3 && gamesB == 3
        default:
            // bestOf3, bestOf5, noAd all use 6-6 tiebreak.
            return gamesA == 6 && gamesB == 6
        }
    }

    /// Rotates the server to the next player / side.
    private func advanceServer() {
        if state.config.matchType == .doubles {
            state.doublesServerIndex = (state.doublesServerIndex + 1) % 4
            state.server = state.config.servingTeam(state.doublesServerIndex)
        } else {
            state.server = (state.server == .A) ? .B : .A
        }
    }
}
