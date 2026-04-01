import Foundation
import AVFoundation

struct VoiceOption: Identifiable, Equatable {
    let id: String          // AVSpeechSynthesisVoice.identifier
    let displayName: String // e.g. "Australian - Female"
    let language: String

    static let defaultOption = VoiceOption(
        id: "__default__",
        displayName: "Default (Australian)",
        language: "en-AU"
    )
}

class ScoreSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = ScoreSpeaker()

    private let synthesizer = AVSpeechSynthesizer()

    @Published var availableVoices: [VoiceOption] = []
    @Published var selectedVoiceId: String
    /// Shows the last spoken text as a visual fallback when TTS is unavailable.
    @Published var announcementText: String? = nil

    private let voicePrefsKey = "selected_voice_id"
    private(set) var hasVoices: Bool = false

    private override init() {
        selectedVoiceId = UserDefaults.standard.string(forKey: voicePrefsKey) ?? VoiceOption.defaultOption.id
        super.init()
        synthesizer.delegate = self
        discoverVoices()
    }

    // MARK: - Voice discovery

    private func discoverVoices() {
        let targetLocales: [String: String] = [
            "en-AU": "Australian",
            "en-GB": "British",
            "en-US": "American",
            "en-IN": "Indian",
            "fr-FR": "French",
            "es-ES": "Spanish",
            "de-DE": "German",
            "it-IT": "Italian"
        ]

        let voices = AVSpeechSynthesisVoice.speechVoices()
        var options: [VoiceOption] = []
        var seenDisplayNames = Set<String>()

        for voice in voices {
            guard let accent = targetLocales[voice.language] else { continue }
            let gender = guessGender(voice)
            let displayName = gender != nil ? "\(accent) - \(gender!)" : accent
            guard !seenDisplayNames.contains(displayName) else { continue }
            seenDisplayNames.insert(displayName)
            options.append(VoiceOption(id: voice.identifier, displayName: displayName, language: voice.language))
        }

        options.sort { $0.displayName < $1.displayName }
        availableVoices = [VoiceOption.defaultOption] + options

        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        hasVoices = !allVoices.isEmpty
        print("[ScoreSpeaker] System has \(allVoices.count) voices. Matched \(options.count) for picker.")
        if allVoices.isEmpty {
            print("[ScoreSpeaker] ⚠️ No TTS voices on this device/simulator — using visual announcements instead.")
        } else {
            let langs = Set(allVoices.map { $0.language }).sorted()
            print("[ScoreSpeaker] Available languages: \(langs)")
        }
    }

    private func guessGender(_ voice: AVSpeechSynthesisVoice) -> String? {
        if #available(iOS 17.0, watchOS 10.0, *) {
            switch voice.gender {
            case .female: return "Female"
            case .male: return "Male"
            default: break
            }
        }
        let nameLower = voice.name.lowercased()
        if nameLower.contains("female") || nameLower.contains("(female)") { return "Female" }
        if nameLower.contains("male") || nameLower.contains("(male)") { return "Male" }
        return nil
    }

    // MARK: - Voice selection

    func setVoice(_ voiceId: String) {
        selectedVoiceId = voiceId
        UserDefaults.standard.set(voiceId, forKey: voicePrefsKey)
    }

    private var resolvedVoice: AVSpeechSynthesisVoice? {
        if selectedVoiceId != VoiceOption.defaultOption.id {
            if let match = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == selectedVoiceId }) {
                return match
            }
        }
        // Preferred languages in order; fall back to any English voice, then any voice at all.
        for lang in ["en-AU", "en-GB", "en-US"] {
            if let voice = AVSpeechSynthesisVoice(language: lang) { return voice }
        }
        if let anyEnglish = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("en") }) {
            return anyEnglish
        }
        return AVSpeechSynthesisVoice.speechVoices().first
    }

    // MARK: - Audio session (ducking)

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("[ScoreSpeaker] Audio session error: \(error)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[ScoreSpeaker] Audio deactivation error: \(error)")
        }
    }

    // MARK: - Public API

    /// Speaks an arbitrary string. Falls back to a visual banner when no voices are available.
    func speak(_ text: String, rate: Float = 0.45) {
        guard !text.isEmpty else { return }
        let voice = resolvedVoice
        print("[ScoreSpeaker] Speaking: \"\(text)\" | voice: \(voice?.name ?? "nil") (\(voice?.language ?? "none"))")

        // Visual announcement — always shown briefly, doubles as fallback on simulator.
        DispatchQueue.main.async {
            self.announcementText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.announcementText == text {
                self.announcementText = nil
            }
        }

        guard hasVoices else { return }
        activateAudioSession()
        let utterance = makeUtterance(text, rate: rate)
        synthesizer.speak(utterance)
    }

    /// Speaks the transition announcement between two states.
    func speakTransition(previous: MatchState, current: MatchState, mode: VoiceCalloutMode) {
        guard mode != .off else { return }
        let withNames = (mode == .withPlayerNames)
        if let text = SpeechFormatter.transitionCall(previous: previous, current: current,
                                                      includePlayerNames: withNames),
           !text.isEmpty {
            speak(text)
        } else {
            let text = SpeechFormatter.fullScoreUpdate(current, includePlayerNames: withNames)
            if !text.isEmpty { speak(text) }
        }
    }

    /// Speaks the full current score.
    func speakFullScore(_ state: MatchState, mode: VoiceCalloutMode) {
        guard mode != .off else { return }
        let withNames = (mode == .withPlayerNames)
        let text = SpeechFormatter.fullScoreUpdate(state, includePlayerNames: withNames)
        if !text.isEmpty { speak(text) }
    }

    /// Previews the selected voice with a sample tennis score.
    func previewVoice() {
        speak("Game, Federer. Federer leads 6 4, 5 3.")
    }

    /// Stops any ongoing speech immediately.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        deactivateAudioSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        deactivateAudioSession()
    }

    // MARK: - Helpers

    private func makeUtterance(_ text: String, rate: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        let voice = resolvedVoice
        if let voice = voice {
            utterance.voice = voice
        } else {
            // Don't set voice at all — let the system pick its own default.
            // Log available voices for debugging.
            let all = AVSpeechSynthesisVoice.speechVoices()
            print("[ScoreSpeaker] No voice resolved. Available voices: \(all.count). Languages: \(Set(all.map { $0.language }).sorted())")
        }
        return utterance
    }
}
