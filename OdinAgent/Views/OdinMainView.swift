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

    private let brainService = OdinBrainService()
    
    @State private var latestResponse = ""
    
    var body: some View {

        VStack(spacing: 20) {

            Image(
                speechService.isSpeaking
                ? mouthAnimationService.currentImageName
                : idleAnimationService.idleImageName
            )
            .resizable()
            .scaledToFit()
            .frame(width: 300, height: 300)

            Text(latestResponse)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(maxWidth: 400)
            
//            Button("Make Odin Talk") {
//                speechService.speak(
//                    "Hello, I am Odin. I can hear you now."
//                )
//            }
        }
        .padding()
        
        .onAppear {

            idleAnimationService.start()

            speechService.onSpeechStarted = { spokenText in

                whisperService.stopListening()
                idleAnimationService.stop()

                let frames =
                    phonemeService.frames(for: spokenText)

                mouthAnimationService.play(frames: frames)
            }

            speechService.onSpeechFinished = {

                mouthAnimationService.stop()
                idleAnimationService.start()

                whisperService.startListening()
            }

            whisperService.onTranscript = { transcript in
                Task {
                    let response = await brainService.respond(to: transcript)
                    
                    await MainActor.run {
                        latestResponse = response
                        speechService.speak(response)
                    }                }
            }
            whisperService.startListening()
        }
    }
}
