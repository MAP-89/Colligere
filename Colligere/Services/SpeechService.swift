import Speech
import AVFoundation

enum SpeechService {

    enum TranscriptionError: Error, LocalizedError {
        case noLocaleSupported
        case modelsUnavailable

        var errorDescription: String? {
            switch self {
            case .noLocaleSupported: "No supported speech locale found for your region."
            case .modelsUnavailable: "Speech recognition models are not available on this device."
            }
        }
    }

    static var isAvailable: Bool { SpeechTranscriber.isAvailable }

    // Transcribes a recorded .m4a file and returns the best text result.
    // Uses SpeechAnalyzer (iOS 26+); falls back gracefully on failure.
    static func transcribe(fileAt url: URL) async throws -> String {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw TranscriptionError.noLocaleSupported
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

        if let installRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installRequest.downloadAndInstall()
        }

        let audioFile = try AVAudioFile(forReading: url)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Autonomous analysis: reads file and finishes the result stream when done
        try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)

        var parts: [String] = []
        for try await result in transcriber.results {
            parts.append(String(result.text.characters))
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
