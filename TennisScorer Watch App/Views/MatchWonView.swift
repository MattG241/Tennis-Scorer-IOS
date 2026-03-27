import SwiftUI

struct MatchWonView: View {

    let state: MatchState
    let onNewMatch: () -> Void

    // MARK: - Colors
    private let courtGreenDark  = Color(red: 0.106, green: 0.369, blue: 0.125)
    private let lightGreen      = Color(red: 0.604, green: 0.804, blue: 0.604)
    private let buttonGreen     = Color(red: 0.188, green: 0.502, blue: 0.188)

    var body: some View {
        ZStack {
            courtGreenDark.ignoresSafeArea()

            VStack(spacing: 6) {
                Text("🏆")
                    .font(.system(size: 32))

                if let winner = state.winner {
                    Text(state.config.teamName(winner))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text("wins!")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(lightGreen)

                Text(ScoreFormatter.finalScore(state))
                    .font(.system(size: 13))
                    .foregroundColor(lightGreen)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 4)

                Button(action: onNewMatch) {
                    Text("New Match")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(buttonGreen)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
        }
    }
}
