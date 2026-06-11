import SwiftUI

struct OdinMainView: View {

    @StateObject private var viewModel: OdinMainViewModel
    @FocusState private var isCommandFieldFocused: Bool

    private var theme: OdinTheme {
        viewModel.isNightMode ? .night : .day
    }

    init(dependencies: OdinDependencyContainer = .live) {
        _viewModel = StateObject(
            wrappedValue: OdinMainViewModel(dependencies: dependencies)
        )
    }

    var body: some View {

        ZStack {
            theme.windowBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                headerBar

                Spacer(minLength: 0)

                speechBubble

                Image(viewModel.currentDogImageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .scaleEffect(viewModel.isHoveringOdin ? 1.035 : 1.0)
                    .animation(.easeOut(duration: 0.18), value: viewModel.isHoveringOdin)
                    .onHover { hovering in
                        viewModel.isHoveringOdin = hovering
                    }
                    .onTapGesture {
                        viewModel.petOdin()
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
        .animation(.easeInOut(duration: 0.20), value: viewModel.isNightMode)
        .onAppear {
            viewModel.start()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text("State: \(viewModel.odinState.displayText)")
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
                viewModel.toggleNightMode()
            } label: {
                Image(systemName: viewModel.isNightMode ? "sun.max.fill" : "moon.fill")
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(viewModel.isNightMode ? "Switch to day mode" : "Switch to night mode")

            Button {
                viewModel.stopSpeaking()
            } label: {
                Image(systemName: "speaker.slash.fill")
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.speechService.isSpeaking)
            .help("Stop speaking")
        }
    }

    private var speechBubble: some View {
        ScrollView {
            Text(viewModel.bubbleText)
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
            Text("State: \(viewModel.odinState.displayText)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            commandControls

            modelPicker
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(theme.commandBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var commandControls: some View {
        HStack(spacing: 10) {
            TextField("Ask Odin...", text: $viewModel.typedCommand)
                .textFieldStyle(.plain)
                .focused($isCommandFieldFocused)
                .font(.system(size: 14))
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    viewModel.submitTypedCommand()
                }
                .disabled(viewModel.odinState.disablesCommands)

            Button {
                viewModel.submitTypedCommand()
            } label: {
                Text("Send")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 54, height: 34)
                    .background(theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.canSubmitTypedCommand)
            .help("Send")
        }
    }

    private var modelPicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .foregroundStyle(theme.primaryText)
                .frame(width: 18, height: 18)

            if viewModel.availableModels.isEmpty {
                Text(viewModel.isLoadingModels ? "Loading Ollama models..." : "No Ollama models found")
                    .font(.caption)
                    .foregroundStyle(theme.primaryText.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Picker("Ollama model", selection: $viewModel.selectedModelName) {
                    ForEach(viewModel.availableModels) { model in
                        Text(model.name)
                            .tag(model.name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(viewModel.odinState.disablesCommands)
            }

            Button {
                viewModel.loadAvailableModels()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoadingModels || viewModel.odinState.disablesCommands)
            .help("Refresh Ollama models")
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(theme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch viewModel.odinState {
        case .thinking:
            return Color(red: 0.88, green: 0.58, blue: 0.18)
        case .speaking:
            return Color(red: 0.19, green: 0.55, blue: 0.88)
        case .listening:
            return Color(red: 0.26, green: 0.64, blue: 0.37)
        case .idle:
            return Color.gray
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
