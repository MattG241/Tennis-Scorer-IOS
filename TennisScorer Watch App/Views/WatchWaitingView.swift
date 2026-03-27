import SwiftUI

struct WatchWaitingView: View {

    @EnvironmentObject var viewModel: WatchMatchViewModel
    @State private var showSetup = false

    // MARK: - Colors
    private let courtGreenDark = Color(red: 0.106, green: 0.369, blue: 0.125)

    var body: some View {
        VStack(spacing: 6) {
            Text("🎾")
                .font(.system(size: 32))

            Text("No match")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)

            Button(action: { showSetup = true }) {
                Text("Setup here")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(courtGreenDark)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Text("or configure on phone")
                .font(.system(size: 10))
                .foregroundColor(Color.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .sheet(isPresented: $showSetup) {
            WatchSetupView(isPresented: $showSetup)
                .environmentObject(viewModel)
        }
    }
}
