import Foundation
import SwiftUI
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var voiceCalloutMode: VoiceCalloutMode {
        didSet { save(voiceCalloutMode, forKey: Keys.voiceCalloutMode) }
    }

    @Published var defaultFormat: MatchFormat {
        didSet { save(defaultFormat, forKey: Keys.defaultFormat) }
    }

    @Published var defaultMatchType: MatchType {
        didSet { save(defaultMatchType, forKey: Keys.defaultMatchType) }
    }

    @Published var themeMode: ThemeMode {
        didSet { save(themeMode, forKey: Keys.themeMode) }
    }

    private enum Keys {
        static let voiceCalloutMode = "voiceCalloutMode"
        static let defaultFormat    = "defaultFormat"
        static let defaultMatchType = "defaultMatchType"
        static let themeMode        = "themeMode"
    }

    private let defaults = UserDefaults.standard

    private init() {
        voiceCalloutMode = Self.load(VoiceCalloutMode.self, forKey: Keys.voiceCalloutMode, defaults: UserDefaults.standard) ?? .withPlayerNames
        defaultFormat    = Self.load(MatchFormat.self,       forKey: Keys.defaultFormat,    defaults: UserDefaults.standard) ?? .bestOf3
        defaultMatchType = Self.load(MatchType.self,         forKey: Keys.defaultMatchType, defaults: UserDefaults.standard) ?? .singles
        themeMode        = Self.load(ThemeMode.self,         forKey: Keys.themeMode,        defaults: UserDefaults.standard) ?? .system
    }

    // MARK: - Persistence helpers

    private func save<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            print("[AppSettings] Failed to save \(key): \(error)")
        }
    }

    private static func load<T: Codable>(_ type: T.Type, forKey key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("[AppSettings] Failed to load \(key): \(error)")
            return nil
        }
    }

    /// Resets all settings to their defaults.
    func resetToDefaults() {
        voiceCalloutMode = .withPlayerNames
        defaultFormat    = .bestOf3
        defaultMatchType = .singles
        themeMode        = .system
    }
}
