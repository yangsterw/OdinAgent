import Foundation
import AVFoundation
import Combine

final class OdinSpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    @Published var isSpeaking = false

    var onSpeechStarted: ((String) -> Void)?
    var onSpeechFinished: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    private func dogify(_ text: String) -> String {
        let prefixes = [
            "Woof.",
            "Ruff.",
            "Bark bark.",
            "Arf."
        ]

        let suffixes = [
            "Woof woof.",
            "Ruff.",
            "Awoo.",
            "Bark."
        ]

        let prefix = prefixes.randomElement() ?? "Woof."
        let suffix = suffixes.randomElement() ?? "Woof."

        return "\(prefix) \(text) \(suffix)"
    }

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let dogText = dogify(text)

        let utterance = AVSpeechUtterance(string: dogText)

        utterance.voice = AVSpeechSynthesisVoice(
            identifier: "com.apple.voice.compact.en-GB.Daniel"
        )

        utterance.rate = Float.random(in: 0.52...0.58)
        utterance.pitchMultiplier = Float.random(in: 1.14...1.22)
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)

        onSpeechStarted?(dogText)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        onSpeechFinished?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.onSpeechFinished?()
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.onSpeechFinished?()
        }
    }
}
