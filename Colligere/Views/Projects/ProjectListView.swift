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
                            HStack(spacing: 0) {
                                ProjectRow(
                                    project: project,
                                    isActive: activeProjectID == project.id.uuidString
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    activeProjectID = project.id.uuidString
                                }

                                NavigationLink(value: project) {
                                    EmptyView()
                                }
                                .frame(width: 28)
                            }
                        }
                        .onDelete(perform: deleteProjects)
                    }
                }
            }
            .navigationTitle("Projects")
            .navigationDestination(for: LanguageProject.self) { project in
                ProjectDetailView(project: project)
            }
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
            let firestoreID = project.firestoreProjectID
            context.delete(project)
            if let firestoreID, !firestoreID.isEmpty {
                Task { await FirestoreService.shared.deleteIndividualProject(byID: firestoreID) }
            }
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
                    if project.firestoreProjectID != nil {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Backed up to cloud")
                    } else {
                        Image(systemName: "icloud.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Not backed up")
                    }
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
    @State private var fieldLatitude: Double?
    @State private var fieldLongitude: Double?
    @State private var fieldLocationName: String?
    @State private var fieldNotes = ""
    @State private var showingLocationPicker = false

    private var canCreate: Bool {
        !languageName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var coordsString: String {
        guard let lat = fieldLatitude, let lng = fieldLongitude else { return "" }
        return String(format: "%.4f, %.4f", lat, lng)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Language") {
                    TextField("Language name (required)", text: $languageName)
                    TextField("Language family (optional)", text: $languageFamily)
                }
                Section {
                    Button {
                        showingLocationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                if let name = fieldLocationName, !name.isEmpty {
                                    Text(name).foregroundStyle(.primary)
                                    Text(coordsString)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                } else if fieldLatitude != nil {
                                    Text(coordsString).foregroundStyle(.primary)
                                } else {
                                    Text("Set field work location").foregroundStyle(.tint)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Field notes (optional)", text: $fieldNotes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Field Work")
                } footer: {
                    Text("Location is approximate and is used to recommend collaborative projects in the same area.")
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
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    latitude: $fieldLatitude,
                    longitude: $fieldLongitude,
                    locationName: $fieldLocationName
                )
            }
        }
    }

    private func createProject() {
        let trimmed = languageName.trimmingCharacters(in: .whitespaces)
        let project = LanguageProject(languageName: trimmed)
        if !languageFamily.isEmpty { project.languageFamily = languageFamily }
        project.fieldLatitude = fieldLatitude
        project.fieldLongitude = fieldLongitude
        project.fieldLocationName = fieldLocationName
        if !fieldNotes.isEmpty { project.fieldNotes = fieldNotes }
        context.insert(project)
        SeedItem.seedProject(project, in: context)
        activeProjectID = project.id.uuidString

        Task { try? await FirestoreService.shared.syncIndividualProject(project) }

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
