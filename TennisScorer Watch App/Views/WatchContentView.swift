import SwiftUI

struct WatchContentView: View {

    @EnvironmentObject var viewModel: WatchMatchViewModel
    @Environment(\.isLuminanceReduced) var isAmbient

    var body: some View {
        if let state = viewModel.state {
            if isAmbient {
                AmbientScoreView(state: state)
            } else if state.winner != nil {
                MatchWonView(state: state, onNewMatch: {
                    viewModel.endMatchAndReset()
                })
            } else {
                MatchControlView()
            }
        } else {
            WatchWaitingView()
        }
    }
}
