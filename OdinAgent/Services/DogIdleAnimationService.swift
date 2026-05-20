//
//  DogIdleAnimationService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//


import Foundation
import Combine

final class DogIdleAnimationService: ObservableObject {

    @Published var idleImageName: String = "odin_REST"

    private var idleTask: Task<Void, Never>?

    func start() {
        idleTask?.cancel()

        idleTask = Task {
            while !Task.isCancelled {

                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.0...5.0) * 1_000_000_000))

                await MainActor.run {
                    self.idleImageName = "odin_BLINK"
                }

                try? await Task.sleep(nanoseconds: 120_000_000)

                await MainActor.run {
                    self.idleImageName = "odin_REST"
                }
            }
        }
    }

    func stop() {
        idleTask?.cancel()
        idleImageName = "odin_REST"
    }
}