import SwiftUI
import SwiftData

struct ElicitationView: View {
    let project: LanguageProject

    @State private var selectedCategory: String = "All"

    private let categoryOrder = [
        "All", "Pronouns", "Core Verbs", "Sentence Frames",
        "Swadesh", "Leipzig-Jakarta", "Numbers",
        "Spatial & Temporal", "Social & Kinship", "Descriptors", "Colors"
    ]

    private var availableCategories: [String] {
        let cats = Set(project.entries.map { $0.category })
        return categoryOrder.filter { $0 == "All" || cats.contains($0) }
    }

    private var filteredEntries: [LexicalEntry] {
        let entries = selectedCategory == "All"
            ? project.entries
            : project.entries.filter { $0.category == selectedCategory }
        return entries.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            return $0.english < $1.english
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                categoryFilter
                if project.entries.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "tray",
                        description: Text("This project has no elicitation entries.")
                    )
                } else {
                    entryList
                }
            }
            .navigationTitle(project.languageName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Priority 1 Progress")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(project.priority1CollectedCount) / \(project.priority1Count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: project.priority1Progress)
                .tint(.green)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.background.secondary)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    Button(category) {
                        selectedCategory = category
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedCategory == category ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.background.secondary)
    }

    private var entryList: some View {
        let entries = filteredEntries
        return List {
            ForEach(entries) { entry in
                NavigationLink {
                    EntryDetailView(entry: entry, allEntries: entries)
                } label: {
                    ElicitationEntryRow(entry: entry)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ElicitationEntryRow: View {
    @Bindable var entry: LexicalEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.collectionStatus.color)
                .frame(width: 10, height: 10)
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
            priorityBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var priorityBadge: some View {
        if entry.priority == 1 {
            Text("P1")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        } else if entry.priority == 2 {
            Text("P2")
                .font(.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
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
    return ElicitationView(project: project)
        .modelContainer(container)
}
