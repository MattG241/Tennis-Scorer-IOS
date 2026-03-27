import SwiftUI

struct WatchSetupView: View {

    @EnvironmentObject var viewModel: WatchMatchViewModel
    @Binding var isPresented: Bool

    @State private var formatIndex = 0
    @State private var serverSide: PlayerSide = .A

    // MARK: - Colors
    private let courtGreenDark  = Color(red: 0.106, green: 0.369, blue: 0.125)
    private let scoreBlue       = Color(red: 0.051, green: 0.278, blue: 0.631)

    let formats: [(MatchFormat, String)] = [
        (.bestOf3,      "Best of 3"),
        (.bestOf5,      "Best of 5"),
        (.shortSets,    "Short Sets"),
        (.noAd,         "No-Ad"),
        (.tiebreakOnly, "Tiebreak")
    ]

    private var selectedFormat: MatchFormat { formats[formatIndex].0 }
    private var selectedFormatLabel: String  { formats[formatIndex].1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                // Title
                Text("Setup")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Format picker box
                Button(action: cycleFormat) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Format")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                        Text(selectedFormatLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("(tap to change)")
                            .font(.system(size: 9))
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Server selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)

                    HStack(spacing: 6) {
                        serverButton(label: "P1 serves", side: .A)
                        serverButton(label: "P2 serves", side: .B)
                    }
                }

                // Start button
                Button(action: startMatch) {
                    Text("Start")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(courtGreenDark)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Back
                Button(action: { isPresented = false }) {
                    Text("← Back")
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
    }

    // MARK: - Helper views

    @ViewBuilder
    private func serverButton(label: String, side: PlayerSide) -> some View {
        let isSelected = serverSide == side
        Button(action: { serverSide = side }) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(isSelected ? scoreBlue : Color.white.opacity(0.08))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func cycleFormat() {
        formatIndex = (formatIndex + 1) % formats.count
    }

    private func startMatch() {
        let config = MatchConfig(
            playerA: "Player 1",
            playerB: "Player 2",
            format: selectedFormat,
            firstServer: serverSide
        )
        viewModel.applyNewConfig(config)
        isPresented = false
    }
}
