import Foundation
import SwiftData

@Model
final class AudioRecording {
    var id: UUID
    var relativeFilePath: String
    var durationSeconds: Double
    var transcription: String?
    var speakerLabel: String?
    var recordedAt: Date
    var entry: LexicalEntry?

    init(relativeFilePath: String, durationSeconds: Double, entry: LexicalEntry) {
        self.id = UUID()
        self.relativeFilePath = relativeFilePath
        self.durationSeconds = durationSeconds
        self.recordedAt = Date()
        self.entry = entry
    }

    var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(relativeFilePath)
    }
}
