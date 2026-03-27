import SwiftUI

@main
struct TennisScorerApp: App {

    @StateObject private var mainViewModel = MainViewModel()
    @StateObject private var settings = AppSettings.shared

    init() {
        // Load persisted matches before the first view renders.
        MatchRepository.shared.loadAll()

        // Start the WatchConnectivity session.
        WatchSyncManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(mainViewModel)
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
        }
    }
}

// MARK: - AppSettings + ColorScheme

extension AppSettings {
    /// Maps the app's ThemeMode setting to a SwiftUI ColorScheme preference.
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}
