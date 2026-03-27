// SpeechFormatter.swift
// TennisScorer – Shared
//
// Generates natural-language strings suitable for text-to-speech output,
// mimicking the cadence and vocabulary of a professional tennis chair umpire.
//
// None of these functions mutate state or produce side-effects.

import Foundation

// MARK: - SpeechFormatter

struct SpeechFormatter {

    // MARK: - Transition Call

    /// Produces a spoken announcement for the transition that just occurred
    /// (game won, set won, or match won). Returns `nil` if the transition
    /// was an ordinary point with no game/set/match completion – the caller
    /// should fall back to `fullScoreUpdate` in that case.
    ///
    /// - Parameters:
    ///   - previous:           State snapshot *before* the point was played.
    ///   - current:            State snapshot *after* the point was played.
    ///   - includePlayerNames: When `false`, generic terms ("the server",
    ///                         "the receiver") replace player names.
    static func transitionCall(previous: MatchState,
                               current:  MatchState,
                               includePlayerNames: Bool) -> String? {

        let config = current.config

        // Helper: name for a side, respecting the includePlayerNames flag.
        func name(_ side: PlayerSide) -> String {
            includePlayerNames ? config.teamName(side) : (side == .A ? "Side A" : "Side B")
        }

        // Helper: ordinal string for a set number (1st, 2nd, 3rd…).
        func ordinal(_ n: Int) -> String {
            switch n {
            case 1:  return "first"
            case 2:  return "second"
            case 3:  return "third"
            case 4:  return "fourth"
            case 5:  return "fifth"
            default: return "\(n)th"
            }
        }

        // --- Match won ---
        if current.winner != nil && previous.winner == nil {
            guard let winner = current.winner else { return nil }
            let winnerName  = name(winner)
            let scoreString = ScoreFormatter.finalScore(current)
            return "\(winnerName) wins the match! \(scoreString)."
        }

        // --- Set won (new set started / games reset) ---
        let previousSetCount = previous.completedSets.count
        let currentSetCount  = current.completedSets.count
        if currentSetCount > previousSetCount, let lastSet = current.completedSets.last {
            let setWinner: PlayerSide = (lastSet.gamesA > lastSet.gamesB) ? .A : .B
            let winnerName = name(setWinner)

            // Count sets for the scoreline.
            var setsA = 0, setsB = 0
            for s in current.completedSets {
                if s.gamesA > s.gamesB { setsA += 1 } else { setsB += 1 }
            }

            let setNumber    = currentSetCount  // 1-based
            let setOrdinal   = ordinal(setNumber)
            let setScoreStr  = "\(lastSet.gamesA) games to \(lastSet.gamesB)"

            // Build "leads X sets to Y" or "sets are level" clause.
            let setsClause: String
            if setsA == setsB {
                setsClause = "Sets are level at \(setsA) all."
            } else {
                let leader = setsA > setsB ? name(.A) : name(.B)
                let ahead  = max(setsA, setsB)
                let behind = min(setsA, setsB)
                setsClause = "\(leader) leads \(ahead) set\(ahead == 1 ? "" : "s") to \(behind)."
            }

            return "Game and set, \(winnerName). \(winnerName) wins the \(setOrdinal) set \(setScoreStr). \(setsClause)"
        }

        // --- Game won (no set change) ---
        let prevGamesTotal = previous.currentGamesA + previous.currentGamesB
        let currGamesTotal = current.currentGamesA  + current.currentGamesB
        // A game was just completed if the totals diverged (reset to 0 is caught
        // by the set-won branch above; here we catch the mid-set case).
        let gameJustWon: Bool = {
            // After a game win the game resets to 0-0, so compare totals before/after.
            // The previous state's game was non-zero and current is zero (reset),
            // OR current games-total is one higher (game added without set win).
            let prevGame = previous.currentGame
            let prevHadPoints = prevGame.rawA > 0 || prevGame.rawB > 0
            let currGameReset = current.currentGame.rawA == 0 && current.currentGame.rawB == 0
            return prevHadPoints && currGameReset && currentSetCount == previousSetCount
        }()

        if gameJustWon {
            // Determine who won the game by seeing whose games-count went up.
            let gameWinnerSide: PlayerSide
            if current.currentGamesA > previous.currentGamesA {
                gameWinnerSide = .A
            } else if current.currentGamesB > previous.currentGamesB {
                gameWinnerSide = .B
            } else {
                // Shouldn't happen – fall back gracefully.
                return nil
            }

            let winnerName = name(gameWinnerSide)
            let gA = current.currentGamesA
            let gB = current.currentGamesB

            let gamesClause: String
            if gA == gB {
                gamesClause = "\(gA) games all."
            } else {
                let leader   = gA > gB ? name(.A) : name(.B)
                let ahead    = max(gA, gB)
                let behind   = min(gA, gB)
                gamesClause  = "\(leader) leads \(ahead) games to \(behind)."
            }

            return "Game, \(winnerName). \(gamesClause)"
        }

        // Ordinary point – no announcement to make.
        return nil
    }

    // MARK: - Full Score Update

    /// Returns a complete spoken score update in chair-umpire style.
    ///
    /// Example outputs:
    ///   "Thirty fifteen."
    ///   "Deuce."
    ///   "Advantage Federer. Federer leads five four in the second set."
    ///
    /// - Parameters:
    ///   - state:              Current match state.
    ///   - includePlayerNames: When `true`, player/team names appear in the call.
    static func fullScoreUpdate(_ state: MatchState, includePlayerNames: Bool) -> String {
        var parts: [String] = []

        // --- Current game score ---
        let pointsString = spokenPoints(state, includePlayerNames: includePlayerNames)
        parts.append(pointsString)

        // --- Current set games (only meaningful when there are games to report) ---
        let gA = state.currentGamesA
        let gB = state.currentGamesB
        let setNumber = state.completedSets.count + 1

        // Skip games clause for tiebreak-only (no sets) or when both are 0 at set start.
        if state.config.format != .tiebreakOnly {
            let gamesClause = spokenGames(
                gamesA: gA,
                gamesB: gB,
                setNumber: setNumber,
                state: state,
                includePlayerNames: includePlayerNames
            )
            if let clause = gamesClause {
                parts.append(clause)
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Private Helpers

    /// Spoken representation of the current game score.
    private static func spokenPoints(_ state: MatchState, includePlayerNames: Bool) -> String {
        let game   = state.currentGame
        let format = state.config.format
        let a      = game.rawA
        let b      = game.rawB

        func name(_ side: PlayerSide) -> String {
            includePlayerNames ? state.config.teamName(side) : (side == .A ? "Side A" : "Side B")
        }

        // Tiebreak: just read the numbers.
        if game.tiebreak {
            return "\(a)-\(b)."
        }

        // No-ad sudden death.
        if format == .noAd && a == 3 && b == 3 {
            return "Deuce."
        }

        // Deuce / advantage.
        if a >= 3 && b >= 3 {
            let diff = a - b
            if diff == 0 { return "Deuce." }
            let advSide = diff > 0 ? PlayerSide.A : PlayerSide.B
            return "Advantage \(name(advSide))."
        }

        // Normal points.
        let labelA = spokenPointLabel(a)
        let labelB = spokenPointLabel(b)

        if a == b {
            switch a {
            case 0: return "Love all."
            case 1: return "Fifteen all."
            case 2: return "Thirty all."
            default: return "Deuce."
            }
        }

        return "\(labelA) \(labelB)."
    }

    /// Spoken representation of the current set game score.
    /// Returns `nil` when no useful information would be conveyed (e.g. 0-0).
    private static func spokenGames(gamesA: Int,
                                    gamesB: Int,
                                    setNumber: Int,
                                    state: MatchState,
                                    includePlayerNames: Bool) -> String? {
        guard gamesA > 0 || gamesB > 0 else { return nil }

        func name(_ side: PlayerSide) -> String {
            includePlayerNames ? state.config.teamName(side) : (side == .A ? "Side A" : "Side B")
        }

        let setOrdinal: String
        switch setNumber {
        case 1:  setOrdinal = "first"
        case 2:  setOrdinal = "second"
        case 3:  setOrdinal = "third"
        case 4:  setOrdinal = "fourth"
        case 5:  setOrdinal = "fifth"
        default: setOrdinal = "\(setNumber)th"
        }

        if gamesA == gamesB {
            return "\(gamesA) all in the \(setOrdinal) set."
        }

        let leader      = gamesA > gamesB ? name(.A) : name(.B)
        let ahead       = max(gamesA, gamesB)
        let behind      = min(gamesA, gamesB)
        return "\(leader) leads \(ahead)-\(behind) in the \(setOrdinal) set."
    }

    /// Maps a raw point count (0–3) to its spoken tennis word.
    private static func spokenPointLabel(_ raw: Int) -> String {
        switch raw {
        case 0:  return "Love"
        case 1:  return "Fifteen"
        case 2:  return "Thirty"
        case 3:  return "Forty"
        default: return "\(raw)"
        }
    }
}
