import SwiftUI

struct WalkoutView: View {

    @EnvironmentObject var viewModel: WatchMatchViewModel
    @State private var playingSide: PlayerSide? = nil

    private let scoreBlue    = Color(red: 0.051, green: 0.278, blue: 0.631)
    private let courtGreen   = Color(red: 0.106, green: 0.369, blue: 0.125)
    private let tennisBall   = Color(red: 0.804, green: 0.863, blue: 0.224)

    var body: some View {
        let config = viewModel.state?.config

        VStack(spacing: 6) {
            Text("🎵")
                .font(.system(size: 22))

            Text("Walkout Songs")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            // Player A button
            if config?.walkoutSongA != nil {
                walkoutButton(
                    side: .A,
                    label: config?.teamName(.A) ?? "Player 1",
                    color: scoreBlue
                )
            }

            // Player B button
            if config?.walkoutSongB != nil {
                walkoutButton(
                    side: .B,
                    label: config?.teamName(.B) ?? "Player 2",
                    color: courtGreen
                )
            }

            // Start Match
            Button(action: {
                playingSide = nil
                viewModel.startMatch()
            }) {
                Text("Start Match")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(tennisBall)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }

    @ViewBuilder
    private func walkoutButton(side: PlayerSide, label: String, color: Color) -> some View {
        let isPlaying = (playingSide == side)

        Button(action: {
            if isPlaying {
                viewModel.stopWalkout()
                playingSide = nil
            } else {
                viewModel.playWalkout(side: side)
                playingSide = side
            }
        }) {
            HStack {
                Text(isPlaying ? "■" : "▶")
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isPlaying ? color.opacity(0.6) : color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
