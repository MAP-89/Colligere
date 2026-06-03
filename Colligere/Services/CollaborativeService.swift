import Foundation
import FirebaseAuth
import FirebaseFunctions

enum CollaborativeServiceError: LocalizedError {
    case notSignedIn
    case nothingToPush
    case invalidResponse
    case projectNotYetSynced

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "Sign in to contribute to a collaborative project."
        case .nothingToPush:
            "No collected entries with phonetic transcriptions to push."
        case .invalidResponse:
            "Unexpected response from the push function."
        case .projectNotYetSynced:
            "Sync this project to the cloud first, then try again."
        }
    }
}

struct PushResult: Sendable {
    let entriesWritten: Int
    let newContributor: Bool
    let consensusUpdates: Int
}

struct EmbeddingResult: Sendable {
    let pairCount: Int
    let dimensions: Int
}

@MainActor
final class CollaborativeService {
    static let shared = CollaborativeService()

    private lazy var functions = Functions.functions()

    private init() {}

    /// Pushes the project's collected, non-private, non-uncertain entries to the
    /// collaborative project document via the `pushToCollaborativeProject` callable.
    /// Updates `project.lastPushedToCollaborativeAt` on success.
    @discardableResult
    func push(project: LanguageProject, to collabProjectID: String) async throws -> PushResult {
        guard Auth.auth().currentUser != nil else {
            throw CollaborativeServiceError.notSignedIn
        }

        // Spec section 4.6: only collected items with a non-empty phonetic, and
        // never private or uncertain ones. Custom entries without a seedItemID
        // are excluded because the collab lexicon is keyed by seedItemID.
        let eligible = project.entries.filter { entry in
            entry.isCollected
                && !entry.phonetic.trimmingCharacters(in: .whitespaces).isEmpty
                && !entry.isPrivate
                && !entry.isUncertain
                && entry.seedItemID != nil
        }

        guard !eligible.isEmpty else {
            throw CollaborativeServiceError.nothingToPush
        }

        let entriesPayload: [[String: Any]] = eligible.map { entry in
            [
                "seedItemID": entry.seedItemID ?? "",
                "english": entry.english,
                "phonetic": entry.phonetic,
                "notes": entry.notes,
                "isPrivate": entry.isPrivate,
                "isUncertain": entry.isUncertain,
            ]
        }

        let payload: [String: Any] = [
            "collabProjectID": collabProjectID,
            "entries": entriesPayload,
        ]

        let result = try await functions
            .httpsCallable("pushToCollaborativeProject")
            .call(payload)

        guard let data = result.data as? [String: Any],
              let entriesWritten = (data["entriesWritten"] as? NSNumber)?.intValue,
              let newContributor = data["newContributor"] as? Bool,
              let consensusUpdates = (data["consensusUpdates"] as? NSNumber)?.intValue
        else {
            throw CollaborativeServiceError.invalidResponse
        }

        project.lastPushedToCollaborativeAt = Date()

        return PushResult(
            entriesWritten: entriesWritten,
            newContributor: newContributor,
            consensusUpdates: consensusUpdates
        )
    }

    /// Calls `generateProjectEmbedding` to compute and persist the project's
    /// Vertex AI lexicon embedding on its Firestore individualProjects doc.
    /// The project must already be synced (have a `firestoreProjectID`).
    @discardableResult
    func generateEmbedding(for project: LanguageProject) async throws -> EmbeddingResult {
        guard Auth.auth().currentUser != nil else {
            throw CollaborativeServiceError.notSignedIn
        }
        guard let projectID = project.firestoreProjectID, !projectID.isEmpty else {
            throw CollaborativeServiceError.projectNotYetSynced
        }

        let eligible = project.entries.filter { entry in
            !entry.english.trimmingCharacters(in: .whitespaces).isEmpty
                && !entry.phonetic.trimmingCharacters(in: .whitespaces).isEmpty
        }

        guard !eligible.isEmpty else {
            throw CollaborativeServiceError.nothingToPush
        }

        let entriesPayload: [[String: Any]] = eligible.map { entry in
            [
                "english": entry.english,
                "phonetic": entry.phonetic,
            ]
        }

        let payload: [String: Any] = [
            "projectID": projectID,
            "entries": entriesPayload,
        ]

        let result = try await functions
            .httpsCallable("generateProjectEmbedding")
            .call(payload)

        guard let data = result.data as? [String: Any],
              let pairCount = (data["pairCount"] as? NSNumber)?.intValue,
              let dimensions = (data["dimensions"] as? NSNumber)?.intValue
        else {
            throw CollaborativeServiceError.invalidResponse
        }

        return EmbeddingResult(pairCount: pairCount, dimensions: dimensions)
    }
}
