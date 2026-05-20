import SwiftUI

struct OdinMainView: View {

    @StateObject private var idleAnimationService =
        DogIdleAnimationService()

    @StateObject private var speechService =
        OdinSpeechService()

    @StateObject private var mouthAnimationService =
        DogMouthAnimationService()

    @StateObject private var whisperService =
        WhisperSoundListeningService()

    private let phonemeService =
        DogPhonemeAnimatorService()

    private let brainService =
        OdinBrainService()

    @State private var odinState = "Idle"

    @State private var latestResponse = ""

    var body: some View {

        VStack(spacing: 20) {

            ZStack {

                Image(
                    speechService.isSpeaking
                    ? mouthAnimationService.currentImageName
                    : idleAnimationService.idleImageName
                )
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 300, height: 300)
            }
            .frame(width: 300, height: 300)
            .clipped()

            Text(latestResponse)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(maxWidth: 400)

            Text("State: \(odinState)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {

            Task { @MainActor in
                odinState = "Listening"
                idleAnimationService.start()
            }

            speechService.onSpeechStarted = { spokenText in

                Task { @MainActor in
                    odinState = "Speaking"

                    whisperService.stopListening()
                    idleAnimationService.stop()

                    let frames =
                        phonemeService.frames(for: spokenText)

                    mouthAnimationService.play(frames: frames)
                }
            }

            speechService.onSpeechFinished = {

                Task { @MainActor in
                    odinState = "Listening"

                    mouthAnimationService.stop()
                    idleAnimationService.start()

                    whisperService.startListening()
                }
            }

            whisperService.onTranscript = { transcript in

                Task { @MainActor in
                    odinState = "Thinking"
                    latestResponse = "Thinking..."
                }

                Task {
                    let response =
                        await brainService.respond(to: transcript)

                    await MainActor.run {
                        latestResponse = response
                        speechService.speak(response)
                    }
                }
            }

            whisperService.startListening()
        }
    }
}
