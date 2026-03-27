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

            // --- MATCH POINT ---
            if format == .tiebreakOnly {
                // Tiebreak-only: winning the game wins the match directly.
                return GameSituation(type: .matchPoint, forSide: side)
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
                    return GameSituation(type: .matchPoint, forSide: side)
                }
            }

            // --- SET POINT ---
            if wouldWinSet {
                return GameSituation(type: .setPoint, forSide: side)
            }
        }

        // --- BREAK POINT ---
        // The *receiver* (non-server side) can win the game.
        for side in PlayerSide.allCases {
            let isReceiver = (side != state.server)
            guard isReceiver else { continue }
            if canWinGameWithNextPoint(side: side, game: game, format: format) {
                return GameSituation(type: .breakPoint, forSide: side)
            }
        }

        // --- GAME POINT ---
        for side in PlayerSide.allCases {
            if canWinGameWithNextPoint(side: side, game: game, format: format) {
                return GameSituation(type: .gamePoint, forSide: side)
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
            // At 3-3 (deuce) it's sudden death – any point wins.
            return maxPts >= 4 || (a == 3 && b == 3)
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
