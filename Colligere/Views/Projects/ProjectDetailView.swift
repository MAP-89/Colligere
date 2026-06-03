import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: LanguageProject

    @AppStorage("activeProjectID") private var activeProjectID: String?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    @State private var showingLocationPicker = false
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var lastSyncedAt: Date?
    @State private var isPushing = false
    @State private var pushError: String?
    @State private var lastPushResult: PushResult?
    @State private var isGeneratingEmbedding = false
    @State private var embeddingError: String?
    @State private var lastEmbeddingResult: EmbeddingResult?

    private var isActive: Bool {
        activeProjectID == project.id.uuidString
    }

    private var isSignedIn: Bool {
        auth.currentUser != nil
    }

    var body: some View {
        Form {
            Section {
                if isActive {
                    Label("This is your active project", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        activeProjectID = project.id.uuidString
                    } label: {
                        Label("Set as Active Project", systemImage: "checkmark.circle")
                    }
                }
            }

            Section("Language") {
                TextField("Language name", text: $project.languageName)
                TextField("Language family (optional)", text: Binding(
                    get: { project.languageFamily ?? "" },
                    set: { project.languageFamily = $0.isEmpty ? nil : $0 }
                ))
            }

            Section {
                Button {
                    showingLocationPicker = true
                } label: {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            if let name = project.fieldLocationName, !name.isEmpty {
                                Text(name).foregroundStyle(.primary)
                                Text(coordsString)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            } else if project.fieldLatitude != nil {
                                Text(coordsString).foregroundStyle(.primary)
                            } else {
                                Text("Set location").foregroundStyle(.tint)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if project.fieldLatitude != nil {
                    Button(role: .destructive) {
                        project.fieldLatitude = nil
                        project.fieldLongitude = nil
                        project.fieldLocationName = nil
                    } label: {
                        Label("Clear Location", systemImage: "mappin.slash")
                    }
                }
            } header: {
                Text("Field Work Location")
            } footer: {
                Text("Used by the matching engine to recommend collaborative projects in the same area.")
            }

            Section("Field Notes") {
                TextField("Notes", text: $project.fieldNotes, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Stats") {
                LabeledContent("Created", value: project.createdAt.formatted(.dateTime.day().month().year()))
                LabeledContent("Entries", value: "\(project.entries.count)")
                LabeledContent("Collected", value: "\(project.collectedCount)")
            }

            cloudSyncSection
            collaborativeTestSection
            embeddingTestSection
        }
        .navigationTitle(project.languageName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                latitude: $project.fieldLatitude,
                longitude: $project.fieldLongitude,
                locationName: $project.fieldLocationName
            )
        }
        .onDisappear {
            guard isSignedIn else { return }
            Task { try? await FirestoreService.shared.syncIndividualProject(project) }
        }
    }

    @ViewBuilder
    private var cloudSyncSection: some View {
        Section {
            if isSignedIn {
                HStack(spacing: 10) {
                    Image(systemName: project.firestoreProjectID == nil ? "icloud.slash" : "checkmark.icloud.fill")
                        .foregroundStyle(project.firestoreProjectID == nil ? Color.secondary : Color.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.firestoreProjectID == nil ? "Not synced yet" : "Backed up to your account")
                            .font(.subheadline.weight(.medium))
                        if let lastSyncedAt {
                            Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if isSyncing {
                        ProgressView().controlSize(.small)
                    }
                }

                Button {
                    Task { await syncNow() }
                } label: {
                    Label(
                        project.firestoreProjectID == nil ? "Back Up to Cloud" : "Sync Now",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(isSyncing)

                if let syncError {
                    Text(syncError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Label("Sign in to back this project up to the cloud.", systemImage: "icloud.slash")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Cloud Sync")
        } footer: {
            Text("Project metadata (name, location, entry counts) syncs to your account so you can be matched with collaborators working on the same language.")
        }
    }

    private func syncNow() async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        do {
            try await FirestoreService.shared.syncIndividualProject(project)
            lastSyncedAt = Date()
        } catch {
            syncError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var collaborativeTestSection: some View {
        Section {
            if isSignedIn {
                HStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Test push to test-collab")
                            .font(.subheadline.weight(.medium))
                        if let lastPushedAt = project.lastPushedToCollaborativeAt {
                            Text("Last pushed \(lastPushedAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never pushed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if isPushing {
                        ProgressView().controlSize(.small)
                    }
                }

                Button {
                    Task { await pushNow() }
                } label: {
                    Label("Push Now", systemImage: "arrow.up.circle")
                }
                .disabled(isPushing)

                if let lastPushResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("\(lastPushResult.entriesWritten) entries written", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        if lastPushResult.newContributor {
                            Text("You were registered as a new contributor.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if lastPushResult.consensusUpdates > 0 {
                            Text("Consensus updated on \(lastPushResult.consensusUpdates) entry(ies).")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let pushError {
                    Text(pushError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Label("Sign in to push to a collaborative project.", systemImage: "person.slash")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Collaborative Project")
        } footer: {
            Text("Developer test — pushes this project's collected entries to the hard-coded `test-collab` collaborative project. Will be replaced with real enrollment + auto-contribute controls.")
        }
    }

    private func pushNow() async {
        isPushing = true
        pushError = nil
        lastPushResult = nil
        defer { isPushing = false }
        do {
            let result = try await CollaborativeService.shared.push(
                project: project,
                to: "test-collab"
            )
            lastPushResult = result
        } catch {
            pushError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var embeddingTestSection: some View {
        Section {
            if isSignedIn {
                HStack(spacing: 10) {
                    Image(systemName: "brain")
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vertex AI embedding")
                            .font(.subheadline.weight(.medium))
                        Text("Generates the lexicon vector used for matching.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isGeneratingEmbedding {
                        ProgressView().controlSize(.small)
                    }
                }

                Button {
                    Task { await generateEmbeddingNow() }
                } label: {
                    Label("Generate Embedding", systemImage: "sparkles")
                }
                .disabled(isGeneratingEmbedding || project.firestoreProjectID == nil)

                if let lastEmbeddingResult {
                    Label(
                        "\(lastEmbeddingResult.dimensions)-dim vector from \(lastEmbeddingResult.pairCount) pairs",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.green)
                }

                if let embeddingError {
                    Text(embeddingError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Label("Sign in to generate an embedding.", systemImage: "person.slash")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Embedding (Test)")
        } footer: {
            Text("Developer test — sends the project's English↔phonetic pairs to Vertex AI text-embedding-005 and stores the 768-dim vector on the Firestore project doc for similarity matching.")
        }
    }

    private func generateEmbeddingNow() async {
        isGeneratingEmbedding = true
        embeddingError = nil
        lastEmbeddingResult = nil
        defer { isGeneratingEmbedding = false }
        do {
            let result = try await CollaborativeService.shared.generateEmbedding(for: project)
            lastEmbeddingResult = result
        } catch {
            embeddingError = error.localizedDescription
        }
    }

    private var coordsString: String {
        guard let lat = project.fieldLatitude, let lng = project.fieldLongitude else {
            return ""
        }
        return String(format: "%.4f, %.4f", lat, lng)
    }
}
