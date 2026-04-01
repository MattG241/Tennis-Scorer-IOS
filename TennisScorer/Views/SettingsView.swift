// SettingsView.swift
// TennisScorer
//
// App settings: defaults, appearance, and about section.

import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Defaults
                Section("Defaults") {
                    // Voice mode
                    Picker("Voice Callouts", selection: $settings.voiceCalloutMode) {
                        ForEach(VoiceCalloutMode.allCases, id: \.self) { mode in
                            Text(mode.displayLabel).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    // Default format
                    Picker("Default Format", selection: $settings.defaultFormat) {
                        ForEach(MatchFormat.allCases, id: \.self) { format in
                            Text(formatLabel(format)).tag(format)
                        }
                    }
                    .pickerStyle(.menu)

                    // Match type
                    Picker("Match Type", selection: $settings.defaultMatchType) {
                        Text("Singles").tag(MatchType.singles)
                        Text("Doubles").tag(MatchType.doubles)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $settings.themeMode) {
                        Label("System",  systemImage: "circle.lefthalf.filled").tag(ThemeMode.system)
                        Label("Light",   systemImage: "sun.max").tag(ThemeMode.light)
                        Label("Dark",    systemImage: "moon").tag(ThemeMode.dark)
                    }
                    .pickerStyle(.menu)
                }

                // MARK: Privacy
                Section("Privacy") {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(TennisColors.courtGreenDark)
                        Text("All match data is stored locally on this device. Nothing is sent to external servers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("Help") {
                        HelpView()
                    }

                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func formatLabel(_ format: MatchFormat) -> String {
        switch format {
        case .bestOf3:      return "Best of 3"
        case .bestOf5:      return "Best of 5"
        case .shortSets:    return "Short Sets"
        case .noAd:         return "No-Ad"
        case .tiebreakOnly: return "Tiebreak Only"
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppSettings.shared)
    }
}
