import SwiftUI
import SwiftData

struct EntryDetailView: View {
    let allEntries: [LexicalEntry]
    @State private var currentIndex: Int
    @FocusState private var isIPAFocused: Bool

    init(entry: LexicalEntry, allEntries: [LexicalEntry]) {
        self.allEntries = allEntries
        _currentIndex = State(initialValue: allEntries.firstIndex(where: { $0.id == entry.id }) ?? 0)
    }

    private var seedItem: SeedItem? {
        guard let sid = allEntries[currentIndex].seedItemID else { return nil }
        return SeedItem.all.first { $0.id == sid }
    }

    var body: some View {
        @Bindable var entry = allEntries[currentIndex]

        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(entry.english)
                            .font(.title2.weight(.semibold))
                        Spacer()
                        statusBadge(for: entry)
                    }
                    if let prompt = seedItem?.prompt {
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Enter IPA transcription…", text: $entry.phonetic)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isIPAFocused)
                        .onChange(of: entry.phonetic) { _, _ in
                            entry.updatedAt = Date()
                        }
                    if let hint = seedItem?.ipaHint, !hint.isEmpty {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }
            } header: {
                Text("Phonetic Transcription")
            }

            Section("Recordings") {
                AudioRecorderView(entry: entry, projectID: entry.project?.id ?? UUID())
            }

            Section("Notes") {
                TextField("Observations, morphology, context…", text: $entry.notes, axis: .vertical)
                    .lineLimit(4...)
                    .onChange(of: entry.notes) { _, _ in
                        entry.updatedAt = Date()
                    }
            }

            Section {
                Toggle("Mark as collected", isOn: $entry.isCollected)
                    .onChange(of: entry.isCollected) { _, _ in
                        entry.updatedAt = Date()
                        if let project = entry.project {
                            FirestoreService.shared.scheduleSync(for: project)
                        }
                    }
                Toggle("Uncertain / needs review", isOn: $entry.isUncertain)
                    .onChange(of: entry.isUncertain) { _, _ in
                        entry.updatedAt = Date()
                    }
            }
        }
        .navigationTitle(entry.english)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isIPAFocused {
                    IPAKeyboardToolbar(text: $entry.phonetic) {
                        isIPAFocused = false
                    }
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    currentIndex -= 1
                    isIPAFocused = false
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex == 0)

                Spacer()

                Text("\(currentIndex + 1) of \(allEntries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    currentIndex += 1
                    isIPAFocused = false
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex == allEntries.count - 1)
            }
        }
    }

    @ViewBuilder
    private func statusBadge(for entry: LexicalEntry) -> some View {
        let status = entry.collectionStatus
        if status != .notStarted {
            Text(status.label)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(status.color.opacity(0.15))
                .foregroundStyle(status.color)
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
    let entries = project.entries.sorted { $0.priority < $1.priority }
    return NavigationStack {
        EntryDetailView(entry: entries[0], allEntries: entries)
    }
    .modelContainer(container)
}
