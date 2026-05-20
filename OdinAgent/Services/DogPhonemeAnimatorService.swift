import Foundation

final class DogPhonemeAnimatorService {

    func frames(for sentence: String) -> [DogMouthFrame] {
        var frames: [DogMouthFrame] = []

        for character in sentence.lowercased() {
            let imageName: String
            let duration: Double

            switch character {
            case "a":
                imageName = "odin_A"
                duration = 0.08

            case "e", "i":
                imageName = "odin_E"
                duration = 0.08

            case "o":
                imageName = "odin_O"
                duration = 0.09

            case "u":
                imageName = "odin_U"
                duration = 0.09

            case "y":
                imageName = "odin_Y"
                duration = 0.08

            case "m", "b", "p":
                imageName = "odin_MBP"
                duration = 0.07

            case "f", "v":
                imageName = "odin_FV"
                duration = 0.07

            case "t", "h":
                imageName = "odin_TH"
                duration = 0.06

            case "l":
                imageName = "odin_L"
                duration = 0.07

            case "r":
                imageName = "odin_R"
                duration = 0.08

            case "s", "z":
                imageName = "odin_S"
                duration = 0.07

            case "c", "j":
                imageName = "odin_SH"
                duration = 0.07

            case "k", "g", "q":
                imageName = "odin_K"
                duration = 0.07

            case "d", "n":
                imageName = "odin_TDN"
                duration = 0.07

            case " ", ".", ",", "!", "?", "\n":
                imageName = "odin_REST"
                duration = 0.12

            default:
                imageName = "odin_REST"
                duration = 0.05
            }

            frames.append(DogMouthFrame(imageName: imageName, duration: duration))
        }

        if frames.isEmpty {
            frames.append(DogMouthFrame(imageName: "odin_REST", duration: 0.2))
        }

        return frames
    }
}
