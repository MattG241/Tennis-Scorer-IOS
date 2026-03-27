import Foundation
import AVFoundation

class ScoreSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = ScoreSpeaker()

    private let synthesizer = AVSpeechSynthesizer()

    /// The preferred voice, resolved once at init.
    private let preferredVoice: AVSpeechSynthesisVoice?

    private override init() {
        preferredVoice = Self.resolveVoice()
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    /// Speaks an arbitrary string.
    func speak(_ text: String, rate: Float = 0.45) {
        guard !text.isEmpty else { return }
        let utterance = makeUtterance(text, rate: rate)
        synthesizer.speak(utterance)
    }

    /// Speaks the transition announcement between two states.
    /// Falls back to a full score update when no transition call is available.
    func speakTransition(previous: MatchState, current: MatchState, mode: VoiceCalloutMode) {
        guard mode != .off else { return }
        if let text = SpeechFormatter.transitionCall(previous: previous, current: current, mode: mode),
           !text.isEmpty {
            speak(text)
        } else if let text = SpeechFormatter.fullScoreUpdate(state: current, mode: mode),
                  !text.isEmpty {
            speak(text)
        }
    }

    /// Speaks the full current score.
    func speakFullScore(_ state: MatchState, mode: VoiceCalloutMode) {
        guard mode != .off else { return }
        if let text = SpeechFormatter.fullScoreUpdate(state: state, mode: mode), !text.isEmpty {
            speak(text)
        }
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
        // Available for subclasses or future use.
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        // Available for subclasses or future use.
    }

    // MARK: - Helpers

    private func makeUtterance(_ text: String, rate: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.voice = preferredVoice
        return utterance
    }

    /// Attempts to find en-AU, then en-GB, then any English voice, then nil (system default).
    private static func resolveVoice() -> AVSpeechSynthesisVoice? {
        let candidates = ["en-AU", "en-GB", "en-US"]
        for locale in candidates {
            if let voice = AVSpeechSynthesisVoice(language: locale) {
                return voice
            }
        }
        // Fall back to the first available English voice.
        let englishVoice = AVSpeechSynthesisVoice.speechVoices().first {
            $0.language.hasPrefix("en")
        }
        return englishVoice
    }
}
