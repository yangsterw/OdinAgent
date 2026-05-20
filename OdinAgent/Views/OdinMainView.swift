import SwiftUI

struct OdinMainView: View {

    @StateObject private var speechService =
        OdinSpeechService()

    @StateObject private var mouthAnimationService =
        DogMouthAnimationService()

    private let phonemeService =
        DogPhonemeAnimatorService()

    var body: some View {

        VStack(spacing: 20) {

            Image(mouthAnimationService.currentImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)

            Button("Make Odin Talk") {

                speechService.onSpeechStarted = { spokenText in

                    let frames =
                        phonemeService.frames(for: spokenText)

                    mouthAnimationService.play(frames: frames)
                }

                speechService.onSpeechFinished = {

                    mouthAnimationService.stop()
                }

                speechService.speak(
                    "Hello, I am Odin. I can hear you now."
                )
            }
        }
        .padding()
    }
}
