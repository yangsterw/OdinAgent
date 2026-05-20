//
//  WhisperSoundListeningService.swift
//  OdinAgent
//

import Foundation
import AVFoundation
import Combine

final class WhisperSoundListeningService:
    ObservableObject,
    SoundListeningService {

    var onTranscript: ((String) -> Void)?

    var isListening: Bool {
        audioEngine.isRunning
    }

    private let audioEngine = AVAudioEngine()

    private var audioSamples: [Float] = []

    private var timer: Timer?

    private let inputSampleRate: Double = 48_000
    private let maxSeconds: Double = 4

    private var whisper: WhisperContext?

    private var isTapInstalled = false

    private var isTranscribing = false

    func startListening() {

        requestMicrophonePermission { [weak self] granted in

            guard let self else { return }

            guard granted else {
                print("Microphone permission denied")
                return
            }

            DispatchQueue.main.async {

                if self.audioEngine.isRunning {
                    print("Whisper already listening")
                    return
                }

                if self.whisper == nil {

                    do {
                        self.whisper = try WhisperContext.create()

                        print("Whisper loaded successfully")

                    } catch {

                        print("Failed to load whisper:", error)
                        return
                    }

                } else {

                    print("Whisper already loaded")
                }

                self.startAudioEngine()
                self.startTranscriptionTimer()
            }
        }
    }

    func stopListening() {

        timer?.invalidate()
        timer = nil

        if isTapInstalled {

            audioEngine.inputNode.removeTap(onBus: 0)

            isTapInstalled = false
        }

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioSamples.removeAll()

        print("Whisper sound service stopped")
    }

    private func requestMicrophonePermission(
        completion: @escaping (Bool) -> Void
    ) {

        switch AVCaptureDevice.authorizationStatus(for: .audio) {

        case .authorized:

            completion(true)

        case .notDetermined:

            AVCaptureDevice.requestAccess(for: .audio) {
                granted in

                completion(granted)
            }

        case .denied, .restricted:

            completion(false)

        @unknown default:

            completion(false)
        }
    }

    private func startAudioEngine() {

        guard !audioEngine.isRunning else {

            print("Audio engine already running")
            return
        }

        let inputNode = audioEngine.inputNode

        if isTapInstalled {

            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        audioEngine.reset()

        let format = inputNode.inputFormat(forBus: 0)

        audioEngine.connect(
            inputNode,
            to: audioEngine.mainMixerNode,
            format: format
        )

        audioEngine.mainMixerNode.outputVolume = 0

        inputNode.installTap(
            onBus: 0,
            bufferSize: 4800,
            format: format
        ) { [weak self] buffer, _ in

            self?.appendBuffer(buffer)
        }

        isTapInstalled = true

        do {

            audioEngine.prepare()

            try audioEngine.start()

            print(
                "Audio engine running:",
                audioEngine.isRunning
            )

        } catch {

            print(
                "Could not start audio engine:",
                error
            )
        }
    }

    private func appendBuffer(_ buffer: AVAudioPCMBuffer) {

        guard buffer.frameLength > 0 else {
            return
        }

        guard let channelData = buffer.floatChannelData else {

            print("No floatChannelData")
            return
        }

        let frameLength = Int(buffer.frameLength)

        let pointer = channelData[0]

        let samples = Array(
            UnsafeBufferPointer(
                start: pointer,
                count: frameLength
            )
        )

        audioSamples.append(contentsOf: samples)

        let maxSamples =
            Int(inputSampleRate * maxSeconds)

        if audioSamples.count > maxSamples {

            audioSamples.removeFirst(
                audioSamples.count - maxSamples
            )
        }
    }

    private func startTranscriptionTimer() {

        timer?.invalidate()

        timer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in

            self?.transcribeCurrentAudio()
        }
    }

    private func transcribeCurrentAudio() {

        guard !isTranscribing else {

            print("Already transcribing; skipping")
            return
        }

        let samples = audioSamples

        guard samples.count > Int(inputSampleRate) else {

            print(
                "Not enough audio yet:",
                samples.count
            )

            return
        }

        isTranscribing = true

        audioSamples.removeAll()

        let samples16k = downsampleTo16k(
            samples,
            inputSampleRate: inputSampleRate
        )

        print("Send to Whisper:", samples16k.count)

        Task {

            guard let whisper else {

                print("Whisper not initialized")

                await MainActor.run {

                    self.isTranscribing = false
                }

                return
            }

            let transcript = await whisper.transcribe(
                samples: samples16k
            )

            print("WHISPER transcript:", transcript)

            await MainActor.run {

                self.isTranscribing = false

                self.handleTranscript(transcript)
            }
        }
    }

    private func handleTranscript(
        _ transcript: String
    ) {

        guard let command =
            commandAfterOdin(from: transcript)
        else {
            return
        }

        print("Odin command:", command)

        onTranscript?(command)
    }

    private func commandAfterOdin(
        from text: String
    ) -> String? {

        let cleaned = text
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z\s]"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        print(
            "Cleaned wake transcript:",
            cleaned
        )

        let prefixes = [
            "hey",
            "hi",
            "okey",
            "okay",
            "ok",
            "yo",
            "you",
            "your",
            "hello"
        ]

        let names = [
            "odin",
            "oden",
            "uden"
        ]

        var wakePhrases: [String] = []

        for prefix in prefixes {

            for name in names {

                wakePhrases.append(
                    "\(prefix) \(name)"
                )
            }
        }

        for phrase in wakePhrases {

            if let range = cleaned.range(of: phrase) {

                let command =
                    cleaned[range.upperBound...]
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                return command.isEmpty
                    ? nil
                    : command
            }
        }

        return nil
    }

    private func downsampleTo16k(
        _ samples: [Float],
        inputSampleRate: Double
    ) -> [Float] {

        let outputSampleRate = 16_000.0

        if abs(
            inputSampleRate - outputSampleRate
        ) < 1 {

            return samples
        }

        let ratio =
            outputSampleRate / inputSampleRate

        let outputCount =
            Int(Double(samples.count) * ratio)

        var output = [Float](
            repeating: 0,
            count: outputCount
        )

        for i in 0..<outputCount {

            let inputIndex =
                Int(Double(i) / ratio)

            if inputIndex < samples.count {

                output[i] = samples[inputIndex]
            }
        }

        return output
    }
}
