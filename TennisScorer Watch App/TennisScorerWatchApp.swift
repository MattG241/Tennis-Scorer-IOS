import SwiftUI
import WatchKit

@main
struct TennisScorerWatchApp: App {

    @StateObject private var viewModel = WatchMatchViewModel()

    init() {
        WatchSyncClient.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(viewModel)
        }
    }
}
