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
    @State private var isHoveringOdin = false
    @State private var isNightMode = false
    @State private var currentBrainTask: Task<Void, Never>?
    @FocusState private var isCommandFieldFocused: Bool

    private var theme: OdinTheme {
        isNightMode ? .night : .day
    }

    var body: some View {

        ZStack {
            theme.windowBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                headerBar

                Spacer(minLength: 0)

                speechBubble

                Image(
                    speechService.isSpeaking
                    ? mouthAnimationService.currentImageName
                    : idleAnimationService.idleImageName
                )
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 300, height: 300)
                .scaleEffect(isHoveringOdin ? 1.035 : 1.0)
                .animation(.easeOut(duration: 0.18), value: isHoveringOdin)
                .onHover { hovering in
                    isHoveringOdin = hovering
                }
                .onTapGesture {
                    petOdin()
                }
                .help("Pet Odin")

                Spacer(minLength: 0)

                commandBar
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 340, idealWidth: 380, maxWidth: .infinity)
        .frame(minHeight: 460, idealHeight: 520, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.20), value: isNightMode)
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

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text("State: \(odinState)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.headerPillBackground)
            .clipShape(Capsule())

            Spacer()

            Button {
                isNightMode.toggle()
            } label: {
                Image(systemName: isNightMode ? "sun.max.fill" : "moon.fill")
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(isNightMode ? "Switch to day mode" : "Switch to night mode")

            Button {
                stopSpeaking()
            } label: {
                Image(systemName: "speaker.slash.fill")
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(!speechService.isSpeaking)
            .help("Stop speaking")
        }
    }

    private var speechBubble: some View {
        ScrollView {
            Text(bubbleText)
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44, maxHeight: 118)
        .background(
            SpeechBubbleShape()
                .fill(theme.bubbleBackground)
                .shadow(color: theme.shadow, radius: 10, x: 0, y: 4)
        )
        .overlay(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.scrollRail)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.trailing, 8)
        }
        .padding(.top, 6)
    }

    private var commandBar: some View {
        VStack(spacing: 8) {
            Text("State: \(odinState)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            commandControls
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(theme.commandBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var commandControls: some View {
        HStack(spacing: 10) {
            TextField("Ask Odin...", text: $typedCommand)
                .textFieldStyle(.plain)
                .focused($isCommandFieldFocused)
                .font(.system(size: 14))
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    submitTypedCommand()
                }
                .disabled(odinState == "Thinking")

            Button {
                submitTypedCommand()
            } label: {
                Text("Send")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 54, height: 34)
                    .background(theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.borderless)
            .disabled(
                typedCommand
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty || odinState == "Thinking"
            )
            .help("Send")
        }
    }

    private var bubbleText: String {
        let response = latestResponse
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if response.isEmpty {
            return defaultBubbleText
        }

        return response
    }

    private var defaultBubbleText: String {
        switch odinState {
        case "Thinking":
            return "Thinking..."
        case "Speaking":
            return latestResponse.isEmpty ? "Awoo." : latestResponse
        case "Listening":
            return "..."
        default:
            return "..."
        }
    }

    private var statusColor: Color {
        switch odinState {
        case "Thinking":
            return Color(red: 0.88, green: 0.58, blue: 0.18)
        case "Speaking":
            return Color(red: 0.19, green: 0.55, blue: 0.88)
        case "Listening":
            return Color(red: 0.26, green: 0.64, blue: 0.37)
        default:
            return Color.gray
        }
    }

    private func stopSpeaking() {
        speechService.stop()
        mouthAnimationService.stop()
        idleAnimationService.start()
        odinState = "Listening"
    }

    private func petOdin() {
        guard odinState != "Thinking" else {
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            latestResponse = "Awoo."
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

private struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - 8
        )

        var path = Path(
            roundedRect: bubbleRect,
            cornerRadius: 16
        )

        path.move(
            to: CGPoint(
                x: rect.midX - 9,
                y: bubbleRect.maxY - 1
            )
        )
        path.addLine(
            to: CGPoint(
                x: rect.midX,
                y: rect.maxY
            )
        )
        path.addLine(
            to: CGPoint(
                x: rect.midX + 9,
                y: bubbleRect.maxY - 1
            )
        )
        path.closeSubpath()

        return path
    }
}

private struct OdinTheme {
    let windowBackground: Color
    let bubbleBackground: Color
    let commandBarBackground: Color
    let headerPillBackground: Color
    let controlBackground: Color
    let primaryText: Color
    let scrollRail: Color
    let shadow: Color

    static let day = OdinTheme(
        windowBackground: Color(red: 0.95, green: 0.94, blue: 0.91),
        bubbleBackground: Color(red: 0.95, green: 0.94, blue: 0.91),
        commandBarBackground: Color(red: 0.95, green: 0.94, blue: 0.91),
        headerPillBackground: Color(red: 0.95, green: 0.94, blue: 0.91)
            .opacity(0.78),
        controlBackground: Color.black.opacity(0.06),
        primaryText: Color(red: 0.16, green: 0.17, blue: 0.17),
        scrollRail: Color.black.opacity(0.72),
        shadow: Color.black.opacity(0.10)
    )

    static let night = OdinTheme(
        windowBackground: Color(red: 0.08, green: 0.09, blue: 0.10),
        bubbleBackground: Color(red: 0.14, green: 0.15, blue: 0.17),
        commandBarBackground: Color(red: 0.12, green: 0.13, blue: 0.15),
        headerPillBackground: Color.white.opacity(0.08),
        controlBackground: Color.white.opacity(0.10),
        primaryText: Color(red: 0.88, green: 0.90, blue: 0.88),
        scrollRail: Color.white.opacity(0.70),
        shadow: Color.black.opacity(0.34)
    )
}
