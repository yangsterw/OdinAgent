import Foundation
import SwiftUI
import Combine

@MainActor
final class OdinViewModel: ObservableObject {

    @Published var dogImageName: String = "odin_SH"
    @Published var isListening: Bool = false
    @Published var statusText: String = "Not listening"
    @Published var latestTranscript: String = ""

    private var soundService: SoundListeningService
    private let animatorService: DogPhonemeAnimatorService

    init(
        soundService: SoundListeningService? = nil,
        animatorService: DogPhonemeAnimatorService = DogPhonemeAnimatorService()
    ) {
        self.soundService = soundService ?? WhisperSoundListeningService()
        self.animatorService = animatorService
        
        self.soundService.onTranscript = { [weak self] transcript in
            Task { @MainActor in
                self?.handleTranscript(transcript)
            }
        }
    }

    func startListening() {
        guard !isListening else { return }

        isListening = true
        statusText = "Listening for Odin..."
        soundService.startListening()
    }

    func stopListening() {
        isListening = false
        statusText = "Stopped"
        soundService.stopListening()
    }

    private func handleTranscript(_ transcript: String) {
        latestTranscript = transcript
        statusText = "Heard: \(transcript)"

        guard let command = commandAfterWakeWord(from: transcript) else {
            statusText = "Heard speech, but no wake word"
            return
        }

        statusText = "Odin says: \(command)"
        animateDogSpeaking(command)
    }

    private func commandAfterWakeWord(from transcript: String) -> String? {
        let lower = transcript.lowercased()

        guard let range = lower.range(of: "odin") else {
            return nil
        }

        let afterWakeWord = transcript[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return afterWakeWord.isEmpty ? nil : afterWakeWord
    }

    private func animateDogSpeaking(_ sentence: String) {
        let frames = animatorService.frames(for: sentence)

        Task { @MainActor in
            for frame in frames {
                dogImageName = frame.imageName
                try? await Task.sleep(nanoseconds: 120_000_000)
            }

            dogImageName = "odin_SH"
        }
    }
}
