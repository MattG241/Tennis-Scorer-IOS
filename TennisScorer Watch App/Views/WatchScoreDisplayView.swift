import SwiftUI

/// Passive score display shown on the watch when scoring is happening on the phone.
/// Shows the live score but no scoring buttons — just a "Switch to Watch" option.
struct WatchScoreDisplayView: View {

    @EnvironmentObject var viewModel: WatchMatchViewModel
    let state: MatchState

    private let tennisBall = Color(red: 0.804, green: 0.863, blue: 0.224)

    var body: some View {
        VStack(spacing: 4) {
            // Set scores
            if !state.completedSets.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(state.completedSets.enumerated()), id: \.offset) { _, set in
                        Text("\(set.gamesA)-\(set.gamesB)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.6))
                    }
                }
            }

            // Current games
            Text("\(state.currentGamesA) – \(state.currentGamesB)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            // Points
            Text(ScoreFormatter.displayPoints(state))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(tennisBall)

            // Server indicator
            let serverName = state.config.servingPlayerName(state.doublesServerIndex)
            HStack(spacing: 4) {
                Circle()
                    .fill(tennisBall)
                    .frame(width: 6, height: 6)
                Text("\(serverName) serving")
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.5))
            }

            Spacer().frame(height: 4)

            // Switch to watch scoring
            Button(action: {
                viewModel.scoringOnPhone = false
            }) {
                Text("Score on Watch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.25))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.075))
    }
}
