//
//  DogPhonemeAnimatorService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//

import Foundation

final class DogPhonemeAnimatorService {

    func frames(for sentence: String) -> [DogMouthFrame] {

        var frames: [DogMouthFrame] = []

        let cleanedSentence = sentence.lowercased()

        for character in cleanedSentence {

            let imageName: String

            switch character {

            // MARK: - Vowels

            case "a":
                imageName = "odin_A"

            case "e", "i":
                imageName = "odin_E"

            case "o":
                imageName = "odin_O"

            case "u":
                imageName = "odin_U"

            case "y":
                imageName = "odin_Y"

            // MARK: - Closed Mouth Sounds

            case "m", "b", "p":
                imageName = "odin_MBP"

            // MARK: - Teeth / Lip Sounds

            case "f", "v":
                imageName = "odin_FV"

            // MARK: - TH Sounds

            case "t", "h":
                imageName = "odin_TH"

            // MARK: - Tongue Sounds

            case "l":
                imageName = "odin_L"

            case "r":
                imageName = "odin_R"

            // MARK: - Sharp Teeth Sounds

            case "s", "z":
                imageName = "odin_S"

            // MARK: - SH / CH / J Sounds

            case "c", "j":
                imageName = "odin_SH"

            // MARK: - Back Mouth Sounds

            case "k", "g", "q":
                imageName = "odin_K"

            // MARK: - T / D / N Sounds

            case "d", "n":
                imageName = "odin_TDN"

            // MARK: - Silence / Space

            case " ", ".", ",", "!", "?", "\n":
                imageName = "odin_REST"

            // MARK: - Default

            default:
                imageName = "odin_REST"
            }

            frames.append(DogMouthFrame(imageName: imageName))
        }

        // fallback if empty
        if frames.isEmpty {
            frames.append(DogMouthFrame(imageName: "odin_REST"))
        }

        return frames
    }
}
