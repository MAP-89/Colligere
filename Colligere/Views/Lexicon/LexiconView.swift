import SwiftUI
import SwiftData

struct LexiconView: View {
    let project: LanguageProject

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedPriority = 0
    @State private var selectedStatus = StatusFilter.all
    @State private var hasAudioOnly = false
    @State private var sortOrder = SortOrder.alphabetical
    @State private var isAddingEntry = false
    @Environment(\.modelContext) private var context

    enum SortOrder: String, CaseIterable, Identifiable {
        var id: Self { self }
        case alphabetical = "A–Z"
        case date = "Date Added"
        case priority = "Priority"
    }

    enum StatusFilter: String, CaseIterable, Identifiable {
        var id: Self { self }
        case all = "Any Status"
        case notStarted = "Not Started"
        case partial = "In Progress"
        case complete = "Complete"

        func matches(_ entry: LexicalEntry) -> Bool {
            switch self {
            case .all: true
            case .notStarted: entry.collectionStatus == .notStarted
            case .partial: entry.collectionStatus == .partial
            case .complete: entry.collectionStatus == .complete
            }
        }
    }

    private let categoryOrder = [
        "All", "Pronouns", "Core Verbs", "Sentence Frames",
        "Swadesh", "Leipzig-Jakarta", "Numbers",
        "Spatial & Temporal", "Social & Kinship", "Descriptors", "Colors"
    ]

    private var filteredEntries: [LexicalEntry] {
        var entries = project.entries

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            entries = entries.filter {
                $0.english.lowercased().contains(query) ||
                $0.phonetic.lowercased().contains(query) ||
                $0.notes.lowercased().contains(query)
            }
        }
        if selectedCategory != "All" {
            entries = entries.filter { $0.category == selectedCategory }
        }
        if selectedPriority != 0 {
            entries = entries.filter { $0.priority == selectedPriority }
        }
        entries = entries.filter { selectedStatus.matches($0) }
        if hasAudioOnly {
            entries = entries.filter { !$0.recordings.isEmpty }
        }

        return entries.sorted { lhs, rhs in
            switch sortOrder {
            case .alphabetical:
                return lhs.english < rhs.english
            case .date:
                return lhs.createdAt > rhs.createdAt
            case .priority:
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.english < rhs.english
            }
        }
    }

    var body: some View {
        let entries = filteredEntries
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        EntryDetailView(entry: entry, allEntries: entries)
                    } label: {
                        LexiconEntryRow(entry: entry)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search English or phonetic")
            .overlay {
                if project.entries.isEmpty {
                    ContentUnavailableView(
                        "Empty Lexicon",
                        systemImage: "book",
                        description: Text("No entries yet. Start collecting in the Elicitation tab.")
                    )
                } else if entries.isEmpty {
                    ContentUnavailableView.search
                }
            }
            .navigationTitle("Lexicon")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort") {
                            Picker("Sort by", selection: $sortOrder) {
                                ForEach(SortOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                        }
                        Section("Filter") {
                            Picker("Status", selection: $selectedStatus) {
                                ForEach(StatusFilter.allCases) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            Picker("Priority", selection: $selectedPriority) {
                                Text("Any Priority").tag(0)
                                Text("P1 — Core").tag(1)
                                Text("P2 — Important").tag(2)
                                Text("P3 — Extended").tag(3)
                            }
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(categoryOrder, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            Toggle("Has Audio", isOn: $hasAudioOnly)
                        }
                    } label: {
                        Label(
                            "Filter",
                            systemImage: isFiltered
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAddingEntry = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingEntry) {
                AddCustomEntrySheet(project: project)
            }
        }
    }

    private var isFiltered: Bool {
        selectedCategory != "All" || selectedPriority != 0 ||
        selectedStatus != .all || hasAudioOnly
    }
}

// MARK: - LexiconEntryRow

private struct LexiconEntryRow: View {
    @Bindable var entry: LexicalEntry

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.collectionStatus.color)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.english)
                    .font(.body)
                if !entry.phonetic.isEmpty {
                    Text(entry.phonetic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if !entry.recordings.isEmpty {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if entry.priority == 1 {
                    Text("P1")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AddCustomEntrySheet

private struct AddCustomEntrySheet: View {
    let project: LanguageProject

    @State private var english = ""
    @State private var category = "Swadesh"
    @State private var priority = 2
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let categories = [
        "Pronouns", "Core Verbs", "Sentence Frames", "Swadesh", "Leipzig-Jakarta",
        "Numbers", "Spatial & Temporal", "Social & Kinship", "Descriptors", "Colors"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Word or Phrase") {
                    TextField("English gloss", text: $english)
                        .autocorrectionDisabled()
                }
                Section("Classification") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Priority", selection: $priority) {
                        Text("P1 — Core").tag(1)
                        Text("P2 — Important").tag(2)
                        Text("P3 — Extended").tag(3)
                    }
                }
            }
            .navigationTitle("Custom Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addEntry()
                        dismiss()
                    }
                    .disabled(english.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addEntry() {
        let entry = LexicalEntry(
            english: english.trimmingCharacters(in: .whitespaces),
            category: category,
            priority: priority,
            project: project
        )
        context.insert(entry)
        project.entries.append(entry)
        FirestoreService.shared.scheduleSync(for: project)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LanguageProject.self, LexicalEntry.self,
            AudioRecording.self, TranslationSession.self,
        configurations: config
    )
    let project = LanguageProject(languageName: "Example Language")
    container.mainContext.insert(project)
    SeedItem.seedProject(project, in: container.mainContext)
    return LexiconView(project: project)
        .modelContainer(container)
}
