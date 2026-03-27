// ScoreFormatter.swift
// TennisScorer – Shared
//
// Pure formatting utilities that convert a `MatchState` into human-readable
// score strings for display in the UI.
//
// None of these functions mutate state or produce side-effects.

import Foundation

// MARK: - ScoreFormatter

struct ScoreFormatter {

    // MARK: - Display Points

    /// Returns a score string for the current game (e.g. "30-15", "Deuce", "Adv. Federer").
    static func displayPoints(_ state: MatchState) -> String {
        let game   = state.currentGame
        let format = state.config.format
        let a      = game.rawA
        let b      = game.rawB

        // --- Tiebreak ---
        if game.tiebreak {
            return "\(a)-\(b)"
        }

        // --- No-Ad: sudden death at 3-3 ---
        if format == .noAd && a == 3 && b == 3 {
            return "Deuce"
        }

        // --- Standard deuce / advantage ---
        if a >= 3 && b >= 3 {
            let diff = a - b
            if diff == 0 {
                return "Deuce"
            }

            // The player with the advantage.
            let advSide: PlayerSide = (diff > 0) ? .A : .B
            let advName = state.config.teamName(advSide)
            return "Adv. \(advName)"
        }

        // --- Normal point labels ---
        let labelA = pointLabel(a)
        let labelB = pointLabel(b)

        // Symmetrical "all" calls.
        if a == b {
            switch a {
            case 0:  return "Love all"
            case 1:  return "15 all"
            case 2:  return "30 all"
            default: return "Deuce"   // 3-3 without no-ad falls here too
            }
        }

        return "\(labelA)-\(labelB)"
    }

    // MARK: - Final Score

    /// Returns a compact multi-set score string for a completed or in-progress match.
    ///
    /// Completed sets are separated by two spaces.
    /// Example: "6-4  7-5" or "6-4  6-3  6-2"
    ///
    /// For TIEBREAK_ONLY the tiebreak score comes from the completed set
    /// (or the live game if the match is still in progress).
    static func finalScore(_ state: MatchState) -> String {
        let format = state.config.format

        if format == .tiebreakOnly {
            // Show the tiebreak game score.
            if let last = state.completedSets.last {
                return "\(last.gamesA)-\(last.gamesB)"
            }
            // Match not yet complete – show live tiebreak.
            return "\(state.currentGame.rawA)-\(state.currentGame.rawB)"
        }

        var parts: [String] = state.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }

        // Append the in-progress set if the match is not over.
        if state.winner == nil {
            parts.append("\(state.currentGamesA)-\(state.currentGamesB)")
        }

        return parts.joined(separator: "  ")
    }

    // MARK: - Format Label

    /// Returns the user-facing name for a `MatchFormat`.
    static func formatLabel(_ format: MatchFormat) -> String {
        switch format {
        case .bestOf3:       return "Best of 3"
        case .bestOf5:       return "Best of 5"
        case .shortSets:     return "Short Sets"
        case .noAd:          return "No-Ad"
        case .tiebreakOnly:  return "Tiebreak"
        }
    }

    // MARK: - Private Helpers

    /// Maps a raw point count (0–3) to its tennis display label.
    private static func pointLabel(_ raw: Int) -> String {
        switch raw {
        case 0:  return "Love"
        case 1:  return "15"
        case 2:  return "30"
        case 3:  return "40"
        default: return "\(raw)"
        }
    }
}
