// Models.swift
// TennisScorer – Shared
//
// Core data structures used throughout the app. All are Codable so they
// can be serialised to JSON for persistence, WCSession transfer, and
// CloudKit sync.

import Foundation

// MARK: - GamePoints

/// The within-game score (raw point counts, not "15/30/40" display labels).
struct GamePoints: Codable, Equatable {
    /// Raw points scored by side A in this game.
    var rawA: Int
    /// Raw points scored by side B in this game.
    var rawB: Int
    /// `true` when this game is being played as a tiebreak.
    var tiebreak: Bool

    init(rawA: Int = 0, rawB: Int = 0, tiebreak: Bool = false) {
        self.rawA = rawA
        self.rawB = rawB
        self.tiebreak = tiebreak
    }
}

// MARK: - SetScore

/// The completed games tally for one set.
struct SetScore: Codable, Equatable {
    var gamesA: Int
    var gamesB: Int
}

// MARK: - MatchConfig

/// Immutable configuration chosen by the user before a match starts.
struct MatchConfig: Codable {

    // MARK: Player names
    var playerA:  String
    var playerB:  String
    /// Second player for side A in doubles. Empty string for singles.
    var playerA2: String
    /// Second player for side B in doubles. Empty string for singles.
    var playerB2: String

    // MARK: Match settings
    var format:      MatchFormat
    var firstServer: PlayerSide
    var matchType:   MatchType

    // MARK: init

    init(
        playerA:     String      = "Player 1",
        playerB:     String      = "Player 2",
        playerA2:    String      = "",
        playerB2:    String      = "",
        format:      MatchFormat = .bestOf3,
        firstServer: PlayerSide  = .A,
        matchType:   MatchType   = .singles
    ) {
        self.playerA     = playerA
        self.playerB     = playerB
        self.playerA2    = playerA2
        self.playerB2    = playerB2
        self.format      = format
        self.firstServer = firstServer
        self.matchType   = matchType
    }

    // MARK: - Helpers

    /// Returns the display name for a team/side.
    /// Singles: just the player name.
    /// Doubles: "Player 1 / Player 3" (partner name separated by " / ").
    func teamName(_ side: PlayerSide) -> String {
        switch side {
        case .A:
            if matchType == .doubles, !playerA2.isEmpty {
                return "\(playerA) / \(playerA2)"
            }
            return playerA
        case .B:
            if matchType == .doubles, !playerB2.isEmpty {
                return "\(playerB) / \(playerB2)"
            }
            return playerB
        }
    }

    /// Returns the name of the specific player currently serving in doubles.
    ///
    /// The doubles serving rotation cycles through all four players in order:
    ///   0 → playerA, 1 → playerB, 2 → playerA2 (falls back to playerA),
    ///   3 → playerB2 (falls back to playerB)
    func servingPlayerName(_ doublesServerIndex: Int) -> String {
        switch doublesServerIndex % 4 {
        case 0: return playerA
        case 1: return playerB
        case 2: return playerA2.isEmpty ? playerA  : playerA2
        case 3: return playerB2.isEmpty ? playerB  : playerB2
        default: return playerA
        }
    }

    /// Returns which team/side is serving for a given doublesServerIndex.
    /// Even indices → side A, odd indices → side B.
    func servingTeam(_ doublesServerIndex: Int) -> PlayerSide {
        return (doublesServerIndex % 2 == 0) ? .A : .B
    }
}

// MARK: - MatchState

/// The full mutable state of a match in progress (or completed).
struct MatchState: Codable, Identifiable {

    // MARK: Identity
    var matchId: String

    // MARK: Configuration
    var config: MatchConfig

    // MARK: Score
    /// Scores for all completed sets, in chronological order.
    var completedSets: [SetScore]
    /// Games won by side A in the current (in-progress) set.
    var currentGamesA: Int
    /// Games won by side B in the current (in-progress) set.
    var currentGamesB: Int
    /// Point-by-point score for the current game.
    var currentGame: GamePoints

    // MARK: Server tracking
    var server: PlayerSide
    /// Doubles only: tracks which of the four players is currently serving (0–3).
    var doublesServerIndex: Int

    // MARK: Match outcome
    /// Non-nil once the match has ended.
    var winner: PlayerSide?
    /// Monotonically increasing counter; incremented on every point played.
    var pointNumber: Int

    // MARK: Timestamps (milliseconds since Unix epoch)
    var startedAtMs: Int64
    var endedAtMs:   Int64

    // MARK: Identifiable
    var id: String { matchId }

    // MARK: init

    init(config: MatchConfig) {
        self.matchId      = UUID().uuidString
        self.config       = config
        self.completedSets = []
        self.currentGamesA = 0
        self.currentGamesB = 0
        self.server        = config.firstServer
        self.doublesServerIndex = (config.firstServer == .A) ? 0 : 1
        self.winner        = nil
        self.pointNumber   = 0
        self.startedAtMs   = Int64(Date().timeIntervalSince1970 * 1000)
        self.endedAtMs     = 0

        // For TIEBREAK_ONLY the very first (and only) game is a tiebreak.
        self.currentGame = GamePoints(tiebreak: config.format == .tiebreakOnly)
    }
}

// MARK: - PointEvent

/// An immutable record of a single point that was played.
struct PointEvent: Codable {
    var matchId:     String
    var pointNumber: Int
    var winner:      PlayerSide
    var tag:         PointTag
    var timestampMs: Int64
}

// MARK: - GameSituation

/// Describes the pressure situation in the current game.
/// Not Codable – always recomputed from live `MatchState`.
struct GameSituation: Equatable {
    var type:    SituationType
    /// Which side the situation is *for* (nil when type is .none).
    var forSide: PlayerSide?

    static let none = GameSituation(type: .none, forSide: nil)

    // Manual Equatable conformance because SituationType is not auto-Equatable.
    static func == (lhs: GameSituation, rhs: GameSituation) -> Bool {
        switch (lhs.type, rhs.type) {
        case (.none,       .none):       return true
        case (.matchPoint, .matchPoint): return lhs.forSide == rhs.forSide
        case (.setPoint,   .setPoint):   return lhs.forSide == rhs.forSide
        case (.breakPoint, .breakPoint): return lhs.forSide == rhs.forSide
        case (.gamePoint,  .gamePoint):  return lhs.forSide == rhs.forSide
        default:                         return false
        }
    }
}
