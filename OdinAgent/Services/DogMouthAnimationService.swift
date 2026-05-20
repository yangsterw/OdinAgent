//
//  DogMouthAnimationService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//


import Foundation
import SwiftUI
import Combine

final class DogMouthAnimationService: ObservableObject {

    @Published var currentImageName: String = "odin_REST"

    private var animationTask: Task<Void, Never>?

    func play(frames: [DogMouthFrame]) {
        animationTask?.cancel()

        animationTask = Task {
            for frame in frames {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.currentImageName = frame.imageName
                }

                let nanoseconds = UInt64(frame.duration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            await MainActor.run {
                self.currentImageName = "odin_REST"
            }
        }
    }

    func stop() {
        animationTask?.cancel()
        currentImageName = "odin_REST"
    }
}
