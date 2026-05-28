import Foundation
import SwiftData

struct SeedItem: Codable, Identifiable {
    let id: String
    let category: String
    let subcategory: String?
    let english: String
    let prompt: String
    let ipaHint: String?
    let priority: Int
    let swadeshNumber: Int?
    let leipzigJakarta: Bool
    let tags: [String]

    static let all: [SeedItem] = loadAll()

    static func loadAll() -> [SeedItem] {
        guard let url = Bundle.main.url(forResource: "SeedWordList", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([SeedItem].self, from: data)) ?? []
    }

    static func seedProject(_ project: LanguageProject, in context: ModelContext) {
        for item in Self.all {
            let entry = LexicalEntry(
                seedItemID: item.id,
                english: item.english,
                category: item.category,
                priority: item.priority,
                project: project
            )
            context.insert(entry)
        }
    }
}
