import Foundation
import FirebaseAuth
import FirebaseFirestore

enum FirestoreSyncError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in to back this project up to the cloud."
        }
    }
}

@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()

    /// Pending debounced sync tasks keyed by the SwiftData project UUID.
    private var pendingSyncTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    private var individualProjects: CollectionReference {
        db.collection("individualProjects")
    }

    private var users: CollectionReference {
        db.collection("users")
    }

    /// Schedules a debounced sync for a project. If called again within the debounce window,
    /// the previous pending sync is cancelled and the timer restarts.
    /// Designed to be safe to call on every entry edit without flooding Firestore.
    func scheduleSync(for project: LanguageProject, after seconds: Double = 30) {
        guard Auth.auth().currentUser != nil else { return }
        let id = project.id
        pendingSyncTasks[id]?.cancel()
        pendingSyncTasks[id] = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            _ = try? await self.syncIndividualProject(project)
        }
    }

    /// Creates or updates the Firestore document for an individual project.
    /// Returns the Firestore document ID; also assigns it to `project.firestoreProjectID` on first sync.
    /// Awaits server acknowledgement so callers see real upload errors (e.g. rules rejections).
    @discardableResult
    func syncIndividualProject(_ project: LanguageProject) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreSyncError.notSignedIn
        }

        let dto = IndividualProjectDTO(from: project, ownerUID: uid)

        if let existing = project.firestoreProjectID, !existing.isEmpty {
            let docRef = individualProjects.document(existing)
            try await setData(dto, on: docRef, merge: true)
            return existing
        }

        let docRef = individualProjects.document()
        try await setData(dto, on: docRef, merge: false)
        project.firestoreProjectID = docRef.documentID

        try await users.document(uid).updateData([
            "projectIDs": FieldValue.arrayUnion([docRef.documentID])
        ])

        return docRef.documentID
    }

    /// Wraps Firestore's completion-based `setData(from:merge:completion:)` in async/await
    /// so callers actually wait for the server (or rules) to acknowledge the write.
    private func setData<T: Encodable>(_ value: T, on ref: DocumentReference, merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try ref.setData(from: value, merge: merge) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Removes the Firestore mirror of a project by its document ID. Best-effort: errors are swallowed
    /// because the caller has already deleted the local copy and there is no rollback path.
    func deleteIndividualProject(byID firestoreID: String) async {
        guard !firestoreID.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        try? await individualProjects.document(firestoreID).delete()
        try? await users.document(uid).updateData([
            "projectIDs": FieldValue.arrayRemove([firestoreID])
        ])
    }
}
