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

            Button("Woof Stop") {
                speechService.stop()
                mouthAnimationService.stop()
                idleAnimationService.start()
                odinState = "Listening"
            }
            .disabled(!speechService.isSpeaking)
            
            Text("State: \(odinState)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView {
                Text(latestResponse)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(12)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 120,
                maxHeight: 220
            )
            .background(
                Color.gray.opacity(0.12)
            )
            .cornerRadius(12)
            .padding(.horizontal, 20)
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
