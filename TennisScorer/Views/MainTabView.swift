// MainTabView.swift
// TennisScorer
//
// Root tab container. Four tabs: Live, Setup, History, Settings.

import SwiftUI

// MARK: - Tab identifiers

enum AppTab: Int {
    case live = 0
    case setup
    case history
    case settings
}

// MARK: - MainTabView

struct MainTabView: View {

    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var settings: AppSettings

    /// Allows programmatic tab switching (e.g. after starting a match).
    @State var selectedTab: AppTab = .live

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: Live tab
            LiveView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Live", systemImage: "bolt.fill")
                }
                .tag(AppTab.live)
                // Red badge dot when a match is active
                .badge(mainViewModel.scoringViewModel != nil ? 1 : 0)

            // MARK: Setup tab
            SetupView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Setup", systemImage: "plus.circle")
                }
                .tag(AppTab.setup)

            // MARK: History tab
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
                .tag(AppTab.history)

            // MARK: Settings tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - Preview

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(MainViewModel())
            .environmentObject(AppSettings.shared)
    }
}
