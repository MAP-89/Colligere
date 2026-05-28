import Foundation
import SwiftData

@Model
final class TranslationSession {
    var id: UUID
    var direction: String
    var inputText: String
    var outputText: String
    var confidence: String?
    var timestamp: Date
    var project: LanguageProject?

    init(
        direction: String,
        inputText: String,
        outputText: String,
        confidence: String?,
        project: LanguageProject
    ) {
        self.id = UUID()
        self.direction = direction
        self.inputText = inputText
        self.outputText = outputText
        self.confidence = confidence
        self.timestamp = Date()
        self.project = project
    }
}
