import SwiftUI

struct AmbientScoreView: View {

    let state: MatchState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 4) {
                // Set scores (small gray)
                Text(ScoreFormatter.setScores(state))
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray.opacity(0.8))

                // Current games (large bold white)
                Text(ScoreFormatter.games(state))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                // Points (medium, off-white / warm white to suggest tennisBall without color)
                Text(ScoreFormatter.points(state))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.85))
            }
            .padding(8)
        }
    }
}
