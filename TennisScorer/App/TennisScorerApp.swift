import SwiftUI

@main
struct TennisScorerApp: App {

    @StateObject private var mainViewModel = MainViewModel()
    @StateObject private var settings = AppSettings.shared

    /// Controls whether the splash screen is visible.
    @State private var splashDone = false

    init() {
        // Load persisted matches before the first view renders.
        MatchRepository.shared.loadAll()

        // Start the WatchConnectivity session.
        WatchSyncManager.shared.activate()

        // Set up Google Cast (Chromecast) discovery.
        CastManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app loads silently underneath the splash.
                MainTabView()
                    .environmentObject(mainViewModel)
                    .environmentObject(settings)
                    .preferredColorScheme(settings.colorScheme)

                // Splash sits on top, fades out, then removes itself.
                if !splashDone {
                    SplashScreenView {
                        splashDone = true
                    }
                    .zIndex(1)
                }
            }
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
