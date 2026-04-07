// SituationDetector.swift
// TennisScorer – Shared
//
// Analyses a `MatchState` snapshot and returns the most significant
// pressure situation currently in play (match point, set point,
// break point, or game point).
//
// The detector is a pure stateless namespace – no stored state,
// no side-effects, always returns the same result for the same input.

import Foundation

// MARK: - SituationDetector

struct SituationDetector {

    // MARK: - Public API

    /// Evaluates the current match state and returns the highest-priority
    /// `GameSituation` that applies.
    ///
    /// Priority order (highest first):
    ///   1. Match point
    ///   2. Set point
    ///   3. Break point
    ///   4. Game point
    ///   5. None
    ///
    /// When both sides satisfy the same tier simultaneously (rare but
    /// possible in no-ad at deuce, or tiebreaks), side A takes priority
    /// in the result so the UI shows a consistent label.
    static func detect(_ state: MatchState) -> GameSituation {
        // A completed match has no live situation.
        guard state.winner == nil else { return .none }

        let config  = state.config
        let game    = state.currentGame
        let format  = config.format
        let gamesA  = state.currentGamesA
        let gamesB  = state.currentGamesB
        let sets    = state.completedSets

        // Count sets won so far for each side.
        var setsWonA = 0
        var setsWonB = 0
        for s in sets {
            if s.gamesA > s.gamesB { setsWonA += 1 } else { setsWonB += 1 }
        }

        // Evaluate each side in priority order.
        for side in PlayerSide.allCases {
            let canWinGame = canWinGameWithNextPoint(side: side, game: game, format: format)
            guard canWinGame else { continue }

            let count = countPointOpportunities(side: side, game: game, format: format)

            // --- MATCH POINT ---
            if format == .tiebreakOnly {
                // Tiebreak-only: winning the game wins the match directly.
                return GameSituation(type: .matchPoint, forSide: side, count: count)
            }

            let wouldWinSet = canWinSetWithNextGame(
                side:   side,
                gamesA: gamesA,
                gamesB: gamesB,
                format: format
            )

            if wouldWinSet {
                let wouldWinMatch = canWinMatchWithNextSet(
                    side:    side,
                    setsWonA: setsWonA,
                    setsWonB: setsWonB,
                    format:  format
                )
                if wouldWinMatch {
                    return GameSituation(type: .matchPoint, forSide: side, count: count)
                }
            }

            // --- SET POINT ---
            if wouldWinSet {
                return GameSituation(type: .setPoint, forSide: side, count: count)
            }
        }

        // --- BREAK POINT ---
        // The *receiver* (non-server side) can win the game.
        for side in PlayerSide.allCases {
            let isReceiver = (side != state.server)
            guard isReceiver else { continue }
            if canWinGameWithNextPoint(side: side, game: game, format: format) {
                let count = countPointOpportunities(side: side, game: game, format: format)
                return GameSituation(type: .breakPoint, forSide: side, count: count)
            }
        }

        // --- GAME POINT ---
        for side in PlayerSide.allCases {
            if canWinGameWithNextPoint(side: side, game: game, format: format) {
                let count = countPointOpportunities(side: side, game: game, format: format)
                return GameSituation(type: .gamePoint, forSide: side, count: count)
            }
        }

        return .none
    }

    // MARK: - Private Helpers

    /// Returns `true` if `side` would win the game if they scored the next point.
    ///
    /// We simulate adding one raw point and apply the same `isGameWon` logic
    /// as `TennisEngine`, keeping both implementations in sync.
    static func canWinGameWithNextPoint(side: PlayerSide,
                                        game: GamePoints,
                                        format: MatchFormat) -> Bool {
        var simulated = game
        if side == .A {
            simulated.rawA += 1
        } else {
            simulated.rawB += 1
        }
        return simulatedIsGameWon(game: simulated, format: format)
    }

    /// Returns `true` if `side` would win the current set if they won one more game.
    static func canWinSetWithNextGame(side: PlayerSide,
                                      gamesA: Int,
                                      gamesB: Int,
                                      format: MatchFormat) -> Bool {
        let simA = gamesA + (side == .A ? 1 : 0)
        let simB = gamesB + (side == .B ? 1 : 0)
        return simulatedIsSetWon(gamesA: simA, gamesB: simB, format: format)
    }

    /// Returns `true` if `side` would win the match if they won one more set.
    static func canWinMatchWithNextSet(side: PlayerSide,
                                       setsWonA: Int,
                                       setsWonB: Int,
                                       format: MatchFormat) -> Bool {
        let simA = setsWonA + (side == .A ? 1 : 0)
        let simB = setsWonB + (side == .B ? 1 : 0)
        let target = (format == .bestOf5) ? 3 : 2
        return simA >= target || simB >= target
    }

    /// Counts how many point opportunities `side` has before the opponent
    /// could equalise. This gives real tennis-style counts:
    ///   0-40 → 3 break points,  15-40 → 2,  30-40 → 1,  Adv → 1, etc.
    ///
    /// For tiebreaks the same principle applies (e.g. 3-6 → 3 set/match points).
    static func countPointOpportunities(side: PlayerSide,
                                         game: GamePoints,
                                         format: MatchFormat) -> Int {
        let myPts  = (side == .A) ? game.rawA : game.rawB
        let oppPts = (side == .A) ? game.rawB : game.rawA

        if game.tiebreak {
            // Tiebreak: first to 7, win by 2.
            // Opportunities = myPts - oppPts when myPts >= 6 and myPts > oppPts.
            // At 6-3 the leader has 3 opportunities (opponent needs 3 to reach 6).
            guard myPts >= 6 && myPts > oppPts else { return 1 }
            return myPts - oppPts
        }

        switch format {
        case .noAd:
            // No-Ad: at 3-3 (deuce) the next point decides — always 1.
            return 1
        default:
            // Standard advantage scoring.
            // At 40-0 (3-0): 3 game points (opponent needs 3 to reach deuce).
            // At 40-15 (3-1): 2 game points.
            // At 40-30 (3-2): 1 game point.
            // At Adv (e.g. 4-3): 1 game point.
            guard myPts >= 3 && myPts > oppPts else { return 1 }
            if oppPts < 3 {
                // Opponent hasn't reached 40 yet: count = 3 - oppPts
                // e.g. 40-0 → 3, 40-15 → 2, 40-30 → 1
                return 3 - oppPts
            }
            // Both at deuce or advantage territory: always 1
            return 1
        }
    }

    // MARK: - Simulation helpers (mirrors TennisEngine logic exactly)

    private static func simulatedIsGameWon(game: GamePoints, format: MatchFormat) -> Bool {
        let a      = game.rawA
        let b      = game.rawB
        let maxPts = max(a, b)
        let diff   = abs(a - b)

        if game.tiebreak {
            return maxPts >= 7 && diff >= 2
        }

        switch format {
        case .noAd:
            // No-Ad: first to 4 raw points wins (mirrors TennisEngine exactly).
            return maxPts >= 4
        default:
            return maxPts >= 4 && diff >= 2
        }
    }

    private static func simulatedIsSetWon(gamesA: Int, gamesB: Int,
                                          format: MatchFormat) -> Bool {
        let maxG = max(gamesA, gamesB)
        let minG = min(gamesA, gamesB)
        let diff = maxG - minG

        switch format {
        case .shortSets:
            return (maxG >= 4 && diff >= 2) || (maxG == 4 && minG == 3)
        default:
            return (maxG >= 6 && diff >= 2) || (maxG == 7 && minG <= 6)
        }
    }
}
