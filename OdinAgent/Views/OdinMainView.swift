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
    @State private var typedCommand = ""
    @State private var currentBrainTask: Task<Void, Never>?

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

            Button("Stop Speaking") {
                speechService.stop()
                mouthAnimationService.stop()
                idleAnimationService.start()
                odinState = "Listening"
            }
            .disabled(!speechService.isSpeaking)

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
            .background(Color.gray.opacity(0.12))
            .cornerRadius(12)
            .padding(.horizontal, 20)

            HStack {
                TextField(
                    "Type a command for Odin...",
                    text: $typedCommand
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    submitTypedCommand()
                }
                .disabled(odinState == "Thinking")

                Button("Send") {
                    submitTypedCommand()
                }
                .disabled(
                    typedCommand
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty || odinState == "Thinking"
                )
            }
            .padding(.horizontal, 20)

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
                handleCommand(transcript)
            }

            whisperService.startListening()
        }
    }

    private func submitTypedCommand() {
        let command = typedCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !command.isEmpty else {
            return
        }

        typedCommand = ""
        handleCommand(command)
    }

    private func handleCommand(_ command: String) {
        Task { @MainActor in
            odinState = "Thinking"
            latestResponse = "Thinking..."
        }

        currentBrainTask?.cancel()
        currentBrainTask = Task {
            let response = await brainService.respond(
                to: command,
                onPartialResponse: { partialResponse in
                    await MainActor.run {
                        latestResponse = partialResponse
                    }
                }
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                latestResponse = response
                speechService.speak(response)
            }
        }
    }
}
