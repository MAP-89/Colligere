import Foundation
import FirebaseFirestore

struct IndividualProjectDTO: Codable {
    var ownerUID: String
    var languageName: String
    var languageFamily: String?
    var fieldLatitude: Double?
    var fieldLongitude: Double?
    var fieldLocationName: String?
    var entryCount: Int
    var collectedEntryCount: Int
    var enrolledInCollaborativeID: String?
    var createdAt: Timestamp
    var updatedAt: Timestamp
}

extension IndividualProjectDTO {
    init(from project: LanguageProject, ownerUID: String) {
        self.ownerUID = ownerUID
        self.languageName = project.languageName
        self.languageFamily = project.languageFamily
        self.fieldLatitude = project.fieldLatitude
        self.fieldLongitude = project.fieldLongitude
        self.fieldLocationName = project.fieldLocationName
        self.entryCount = project.entries.count
        self.collectedEntryCount = project.collectedCount
        self.enrolledInCollaborativeID = project.collaborativeProjectID
        self.createdAt = Timestamp(date: project.createdAt)
        self.updatedAt = Timestamp(date: Date())
    }
}
