import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LanguageProject.createdAt, order: .reverse) private var projects: [LanguageProject]
    @AppStorage("activeProjectID") private var activeProjectID: String?
    @State private var showingCreateSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap + to create your first language documentation project")
                    )
                } else {
                    List {
                        ForEach(projects) { project in
                            ProjectRow(
                                project: project,
                                isActive: activeProjectID == project.id.uuidString
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                activeProjectID = project.id.uuidString
                            }
                        }
                        .onDelete(perform: deleteProjects)
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Project", systemImage: "plus") {
                        showingCreateSheet = true
                    }
                }
                if !projects.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateProjectSheet()
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = projects[index]
            if activeProjectID == project.id.uuidString {
                activeProjectID = nil
            }
            context.delete(project)
        }
    }
}

struct ProjectRow: View {
    let project: LanguageProject
    let isActive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(project.languageName)
                        .font(.headline)
                    if isActive {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15))
                            .foregroundStyle(.tint)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 12) {
                    if project.entries.isEmpty {
                        Label("No entries yet", systemImage: "tray")
                    } else {
                        Label("\(project.collectedCount)/\(project.entries.count) collected", systemImage: "checkmark.circle")
                    }
                    if let location = project.fieldLocationName ?? project.fieldLocation {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CreateProjectSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("activeProjectID") private var activeProjectID: String?

    @State private var languageName = ""
    @State private var languageFamily = ""
    @State private var fieldLocation = ""
    @State private var fieldNotes = ""

    private var canCreate: Bool {
        !languageName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Language") {
                    TextField("Language name (required)", text: $languageName)
                    TextField("Language family (optional)", text: $languageFamily)
                }
                Section("Field Work") {
                    TextField("Field location (e.g. Ranong Province, Thailand)", text: $fieldLocation)
                    TextField("Field notes", text: $fieldNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Text("Creating this project will pre-populate the elicitation checklist with \(SeedItem.loadAll().count) items derived from the Swadesh 200, Leipzig-Jakarta 100, and supplemental grammatical categories.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProject() }
                        .disabled(!canCreate)
                }
            }
        }
    }

    private func createProject() {
        let trimmed = languageName.trimmingCharacters(in: .whitespaces)
        let project = LanguageProject(languageName: trimmed)
        if !languageFamily.isEmpty { project.languageFamily = languageFamily }
        if !fieldLocation.isEmpty { project.fieldLocation = fieldLocation }
        if !fieldNotes.isEmpty { project.fieldNotes = fieldNotes }
        context.insert(project)
        SeedItem.seedProject(project, in: context)
        activeProjectID = project.id.uuidString
        dismiss()
    }
}

#Preview {
    ProjectListView()
        .modelContainer(for: [
            LanguageProject.self,
            LexicalEntry.self,
            AudioRecording.self,
            TranslationSession.self
        ], inMemory: true)
}
