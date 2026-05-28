import Foundation
import SwiftData
import SwiftUI

@Model
final class LexicalEntry {
    var id: UUID
    var seedItemID: String?
    var english: String
    var phonetic: String
    var notes: String
    var category: String
    var priority: Int
    var isCollected: Bool
    var isPrivate: Bool
    var isUncertain: Bool
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \AudioRecording.entry)
    var recordings: [AudioRecording]
    var project: LanguageProject?

    init(
        seedItemID: String? = nil,
        english: String,
        category: String,
        priority: Int,
        project: LanguageProject
    ) {
        self.id = UUID()
        self.seedItemID = seedItemID
        self.english = english
        self.phonetic = ""
        self.notes = ""
        self.category = category
        self.priority = priority
        self.isCollected = false
        self.isPrivate = false
        self.isUncertain = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.recordings = []
        self.project = project
    }

    var collectionStatus: CollectionStatus {
        if isCollected { return .complete }
        if !phonetic.isEmpty || !recordings.isEmpty { return .partial }
        return .notStarted
    }
}

enum CollectionStatus {
    case notStarted, partial, complete

    var label: String {
        switch self {
        case .notStarted: "Not started"
        case .partial: "In progress"
        case .complete: "Complete"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: Color(.systemGray4)
        case .partial: .orange
        case .complete: .green
        }
    }
}
