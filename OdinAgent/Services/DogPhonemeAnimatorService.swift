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

        for character in sentence.lowercased() {
            let imageName: String

            switch character {
            case "a":
                imageName = "odin_A"
            case "e":
                imageName = "odin_E"
            case "i":
                imageName = "odin_I"
            case "o":
                imageName = "odin_O"
            case "u":
                imageName = "odin_U"
            default:
                imageName = "odin_SH"
            }

            frames.append(DogMouthFrame(imageName: imageName))
        }

        if frames.isEmpty {
            frames.append(DogMouthFrame(imageName: "odin_SH"))
        }

        return frames
    }
}