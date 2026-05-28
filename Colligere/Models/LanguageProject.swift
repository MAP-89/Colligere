import Foundation
import SwiftData

@Model
final class LanguageProject {
    var id: UUID
    var languageName: String
    var languageFamily: String?
    var fieldLocation: String?
    var fieldLocationName: String?
    var fieldLatitude: Double?
    var fieldLongitude: Double?
    var fieldNotes: String
    var createdAt: Date
    var lastTrainedAt: Date?
    var modelVersion: Int
    @Relationship(deleteRule: .cascade, inverse: \LexicalEntry.project)
    var entries: [LexicalEntry]
    @Relationship(deleteRule: .cascade, inverse: \TranslationSession.project)
    var translationSessions: [TranslationSession]
    var firestoreProjectID: String?
    var collaborativeProjectID: String?
    var collaborativeEnrolledAt: Date?
    var lastPushedToCollaborativeAt: Date?
    var autoContributeEnabled: Bool

    init(languageName: String) {
        self.id = UUID()
        self.languageName = languageName
        self.fieldNotes = ""
        self.createdAt = Date()
        self.modelVersion = 0
        self.entries = []
        self.translationSessions = []
        self.autoContributeEnabled = true
    }

    var collectedCount: Int {
        entries.filter { $0.isCollected }.count
    }

    var priority1Count: Int {
        entries.filter { $0.priority == 1 }.count
    }

    var priority1CollectedCount: Int {
        entries.filter { $0.priority == 1 && $0.isCollected }.count
    }

    var priority1Progress: Double {
        guard priority1Count > 0 else { return 0 }
        return Double(priority1CollectedCount) / Double(priority1Count)
    }
}
