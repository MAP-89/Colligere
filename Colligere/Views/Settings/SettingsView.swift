import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import FirebaseAuth

struct SettingsView: View {
    @AppStorage("activeProjectID") private var activeProjectID: String?
    @Query private var projects: [LanguageProject]
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth

    @State private var apiKeyInput = ""
    @State private var isAPIKeyVisible = false
    @State private var keychainError: String?
    @State private var saveConfirmed = false
    @State private var isArchiving = false
    @State private var archiveURL: URL?
    @State private var isShowingArchiveShare = false
    @State private var isImporting = false
    @State private var importError: String?

    private var activeProject: LanguageProject? {
        guard let id = activeProjectID.flatMap(UUID.init) else { return nil }
        return projects.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                apiKeySection
                if let project = activeProject {
                    modelSection(project: project)
                    exportSection(project: project)
                }
                importSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear { loadAPIKey() }
            .sheet(isPresented: $isShowingArchiveShare, onDismiss: { archiveURL = nil }) {
                if let url = archiveURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                importLexicon(result: result)
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            if let user = auth.currentUser {
                if let email = user.email, !email.isEmpty {
                    LabeledContent("Signed in as", value: email)
                } else {
                    LabeledContent("Signed in", value: user.uid.prefix(8) + "…")
                }
                Button("Sign Out", role: .destructive) { auth.signOut() }
            } else {
                Label("Not signed in", systemImage: "person.slash")
                    .foregroundStyle(.secondary)
                Button("Sign In") { auth.hasSkippedSignIn = false }
            }
        }
    }

    private var apiKeySection: some View {
        Section {
            HStack {
                if isAPIKeyVisible {
                    TextField("sk-ant-…", text: $apiKeyInput)
                        .font(.system(.caption, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("sk-ant-…", text: $apiKeyInput)
                        .font(.system(.caption, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Button {
                    isAPIKeyVisible.toggle()
                } label: {
                    Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(saveConfirmed ? "Saved!" : "Save API Key") {
                saveAPIKey()
            }
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

            if let err = keychainError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Anthropic API Key")
        } footer: {
            Text("Stored securely in the system Keychain. Never saved to iCloud or UserDefaults.")
        }
    }

    private func modelSection(project: LanguageProject) -> some View {
        Section {
            LabeledContent("Model Version", value: "v\(project.modelVersion)")
            if let trained = project.lastTrainedAt {
                LabeledContent("Last Refreshed", value: trained.formatted(.relative(presentation: .named)))
            } else {
                LabeledContent("Last Refreshed", value: "Never")
            }
            Button("Refresh Prompt Context") {
                project.modelVersion += 1
                project.lastTrainedAt = Date()
            }
        } header: {
            Text("Translation Model")
        } footer: {
            Text("Refreshing rebuilds the few-shot context from your latest lexicon entries. No local model file is created — the AI uses your lexicon as context on each request.")
        }
    }

    private func exportSection(project: LanguageProject) -> some View {
        Section("Export") {
            ShareLink(
                item: lexiconJSONString(for: project),
                preview: SharePreview("\(project.languageName) Lexicon")
            ) {
                Label("Export Lexicon (JSON)", systemImage: "square.and.arrow.up")
            }

            Button {
                Task { await createAndShareArchive(for: project) }
            } label: {
                Label(
                    isArchiving ? "Creating Archive…" : "Export Full Archive (ZIP)",
                    systemImage: "archivebox"
                )
            }
            .disabled(isArchiving)
        }
    }

    private var importSection: some View {
        Section {
            Button {
                importError = nil
                isImporting = true
            } label: {
                Label("Import Lexicon (JSON)", systemImage: "square.and.arrow.down")
            }
            if let err = importError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Import")
        } footer: {
            Text("Creates a new project from a previously exported lexicon JSON file.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: "Colligere")
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
        }
    }

    // MARK: - Helpers

    private func loadAPIKey() {
        apiKeyInput = KeychainService.load(account: KeychainService.anthropicKeyAccount) ?? ""
    }

    private func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
        do {
            if key.isEmpty {
                KeychainService.delete(account: KeychainService.anthropicKeyAccount)
            } else {
                try KeychainService.save(key, account: KeychainService.anthropicKeyAccount)
            }
            keychainError = nil
            saveConfirmed = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                saveConfirmed = false
            }
        } catch {
            keychainError = error.localizedDescription
        }
    }

    private func lexiconJSONString(for project: LanguageProject) -> String {
        guard let data = try? ExportService.lexiconData(for: project) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func createAndShareArchive(for project: LanguageProject) async {
        isArchiving = true
        do {
            archiveURL = try ExportService.createArchiveURL(for: project)
            isShowingArchiveShare = true
        } catch {
            // silently fail — the JSON export remains available
        }
        isArchiving = false
    }

    private func importLexicon(result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

            let imported = try ExportService.importLexicon(from: url)
            let project = LanguageProject(languageName: imported.languageName)
            context.insert(project)

            for e in imported.entries {
                let entry = LexicalEntry(
                    english: e.english,
                    category: e.category.isEmpty ? "Swadesh" : e.category,
                    priority: e.priority == 0 ? 2 : e.priority,
                    project: project
                )
                entry.phonetic = e.phonetic
                entry.notes = e.notes
                context.insert(entry)
                project.entries.append(entry)
            }
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LanguageProject.self, LexicalEntry.self,
            AudioRecording.self, TranslationSession.self,
        configurations: config
    )
    return SettingsView()
        .modelContainer(container)
}
