// Enums.swift
// TennisScorer – Shared
//
// All application-wide enumerations. Every enum that crosses a module
// boundary (iOS app ↔ Watch extension, persistence, WCSession messages)
// is Codable so it round-trips cleanly through JSON / UserDefaults.

import Foundation

// MARK: - PlayerSide

/// Identifies one of the two players / teams in a match.
enum PlayerSide: String, Codable, CaseIterable {
    case A
    case B
}

// MARK: - MatchType

/// Whether the match is singles or doubles.
enum MatchType: String, Codable, CaseIterable {
    case singles = "SINGLES"
    case doubles = "DOUBLES"
}

// MARK: - MatchFormat

/// The scoring format used for the match.
enum MatchFormat: String, Codable, CaseIterable {
    /// Standard best-of-3 sets with advantage games and a 7-point tiebreak at 6-6.
    case bestOf3        = "BEST_OF_3"
    /// Best-of-5 sets (used in Grand Slams / Davis Cup).
    case bestOf5        = "BEST_OF_5"
    /// Short / fast4-style sets: first to 4 games, tiebreak at 3-3.
    case shortSets      = "SHORT_SETS"
    /// Standard sets but no-advantage games (sudden death at deuce).
    case noAd           = "NO_AD"
    /// A single tiebreak game to 7 (or 10) decides the match.
    case tiebreakOnly   = "TIEBREAK_ONLY"
}

// MARK: - PointTag

/// Qualitative label attached to a scored point for statistics.
enum PointTag: String, Codable, CaseIterable {
    case normal         = "NORMAL"
    case ace            = "ACE"
    case doubleFault    = "DOUBLE_FAULT"
    case winner         = "WINNER"
    case unforcedError  = "UNFORCED_ERROR"
}

// MARK: - ServeType

/// First or second serve within a point.
enum ServeType: String, Codable {
    case first  = "FIRST"
    case second = "SECOND"
}

// MARK: - VoiceCalloutMode

/// Controls how verbose the automated voice announcements are.
enum VoiceCalloutMode: String, Codable, CaseIterable {
    /// No voice announcements.
    case off
    /// Announces score only (e.g. "Thirty fifteen").
    case scoreOnly
    /// Score plus match situation (e.g. "Match point").
    case withSituation
    /// Full call including player names (e.g. "Federer leads…").
    case withPlayerNames

    /// Human-readable label shown in Settings UI.
    var displayLabel: String {
        switch self {
        case .off:              return "Off"
        case .scoreOnly:        return "Score Only"
        case .withSituation:    return "Score + Situation"
        case .withPlayerNames:  return "Full (with Names)"
        }
    }
}

// MARK: - SituationType

/// The pressure situation that applies to the current game.
/// Not Codable – computed on the fly and never persisted.
enum SituationType {
    /// No special situation.
    case none
    /// Winning the next point wins the match.
    case matchPoint
    /// Winning the next point wins the current set.
    case setPoint
    /// The receiver can win the current game (break the serve).
    case breakPoint
    /// Any player can win the current game with the next point.
    case gamePoint
}

// MARK: - ThemeMode

/// UI colour-scheme preference.
enum ThemeMode: String, Codable, CaseIterable {
    /// Follow the system light/dark setting.
    case system
    case light
    case dark
}
