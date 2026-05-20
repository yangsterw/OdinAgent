import Foundation

final class WhisperContext {

    private var context: OpaquePointer?

    private init(context: OpaquePointer) {
        self.context = context
    }

    deinit {
        if let context {
            whisper_free(context)
        }
    }

    static func create() throws -> WhisperContext {

        guard let modelPath = Bundle.main.path(
            forResource: "ggml-base.en",
            ofType: "bin"
        ) else {
            throw NSError(
                domain: "WhisperContext",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Could not find ggml-base.en.bin"
                ]
            )
        }

        print("Loading Whisper model from:", modelPath)

        let initParams = whisper_context_default_params()

        guard let context = whisper_init_from_file_with_params(
            modelPath,
            initParams
        ) else {
            throw NSError(
                domain: "WhisperContext",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to initialize Whisper model"
                ]
            )
        }

        print("Whisper model loaded successfully")

        return WhisperContext(context: context)
    }

    func transcribe(samples: [Float]) async -> String {

        guard let context else {
            print("Whisper context missing")
            return ""
        }

        guard !samples.isEmpty else {
            print("No samples provided")
            return ""
        }

        return await Task.detached(priority: .userInitiated) {

            var params = whisper_full_default_params(
                WHISPER_SAMPLING_GREEDY
            )

            params.print_realtime = false
            params.print_progress = false
            params.print_timestamps = false
            params.print_special = false

            params.translate = false

            params.language = UnsafePointer(strdup("en"))

            params.n_threads = 4
            params.offset_ms = 0
            params.duration_ms = 0

            let result = samples.withUnsafeBufferPointer { buffer -> Int32 in

                guard let baseAddress = buffer.baseAddress else {
                    return -1
                }

                return whisper_full(
                    context,
                    params,
                    baseAddress,
                    Int32(samples.count)
                )
            }

            if let languagePointer = params.language {
                free(
                    UnsafeMutableRawPointer(
                        mutating: languagePointer
                    )
                )
            }

            guard result == 0 else {
                print("whisper_full failed:", result)
                return ""
            }

            let segmentCount = whisper_full_n_segments(context)

            var transcript = ""

            for i in 0..<segmentCount {

                if let cText = whisper_full_get_segment_text(
                    context,
                    i
                ) {
                    transcript += String(cString: cText)
                }
            }

            let cleaned = transcript.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

//            print("WHISPER TRANSCRIPT:", cleaned)

            return cleaned

        }.value
    }
}
