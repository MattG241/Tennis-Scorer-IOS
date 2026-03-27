// TennisColors.swift
// TennisScorer
//
// Central colour palette for the app. Import SwiftUI and reference
// TennisColors.<name> anywhere a Color is needed.

import SwiftUI

// MARK: - TennisColors

enum TennisColors {
    /// Dark court-green used for backgrounds and primary actions.
    /// Hex #1B5E20
    static let courtGreenDark = Color(red: 0.106, green: 0.369, blue: 0.125)

    /// Score-display blue.
    /// Hex #0D47A1
    static let scoreBlue = Color(red: 0.051, green: 0.278, blue: 0.631)

    /// Tennis-ball yellow-green used for highlights and accents.
    /// Hex #CDDC39
    static let tennisBall = Color(red: 0.804, green: 0.863, blue: 0.224)

    /// Score red used for Player B or warning states.
    /// Hex #E91E63
    static let scoreRed = Color(red: 0.914, green: 0.118, blue: 0.388)

    /// Gold used for match-point badges and trophies.
    /// Hex #FFD600
    static let matchPointGold = Color(red: 1.0, green: 0.839, blue: 0.0)
}

// MARK: - Convenience Color extensions

extension Color {
    static var courtGreenDark: Color { TennisColors.courtGreenDark }
    static var scoreBlue:      Color { TennisColors.scoreBlue }
    static var tennisBall:     Color { TennisColors.tennisBall }
    static var scoreRed:       Color { TennisColors.scoreRed }
    static var matchPointGold: Color { TennisColors.matchPointGold }
}
