//
//  MockSoundListeningService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//


import Foundation

final class MockSoundListeningService: SoundListeningService {

    var onTranscript: ((String) -> Void)?

    private var timer: Timer?

    func startListening() {
        print("Mock sound service started")

        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            self?.onTranscript?("odin hello I am your dog assistant")
        }
    }

    func stopListening() {
        print("Mock sound service stopped")

        timer?.invalidate()
        timer = nil
    }
}