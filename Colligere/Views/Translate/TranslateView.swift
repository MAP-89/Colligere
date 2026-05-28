import SwiftUI
import SwiftData

struct TranslateView: View {
    let project: LanguageProject

    @State private var inputText = ""
    @State private var direction = TranslationDirection.englishToTarget
    @State private var result: TranslationResult?
    @State private var isTranslating = false
    @Environment(\.modelContext) private var context

    @Query(sort: \TranslationSession.timestamp, order: .reverse)
    private var allSessions: [TranslationSession]

    private var recentSessions: [TranslationSession] {
        allSessions.filter { $0.project?.id == project.id }
    }

    init(project: LanguageProject) {
        self.project = project
    }

    private var apiKey: String? {
        let key = KeychainService.load(account: KeychainService.anthropicKeyAccount)
        return key?.isEmpty == false ? key : nil
    }

    private var hasEnoughEntries: Bool {
        project.entries.filter { !$0.phonetic.isEmpty }.count >= 5
    }

    private var canTranslate: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty &&
        (apiKey != nil || hasEnoughEntries)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBanner
                    inputCard
                    if let result {
                        outputCard(result)
                    }
                    if !recentSessions.isEmpty {
                        historySection
                    }
                }
                .padding()
            }
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: apiKey != nil ? "cloud.fill" : "internaldrive")
                .foregroundStyle(apiKey != nil ? Color.green : Color.secondary)
            Text(apiKey != nil ? "Cloud inference (Anthropic)" : "Offline — dictionary lookup only")
                .font(.caption.weight(.medium))
                .foregroundStyle(apiKey != nil ? Color.green : Color.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            (apiKey != nil ? Color.green : Color.secondary).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    // MARK: - Input card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Direction", selection: $direction) {
                ForEach(TranslationDirection.allCases) { dir in
                    Text(dir.label).tag(dir)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: direction) { _, _ in
                result = nil
            }

            TextField(
                direction == .englishToTarget ? "Enter English text…" : "Enter \(project.languageName) text…",
                text: $inputText,
                axis: .vertical
            )
            .lineLimit(3...)
            .font(.body)
            .autocorrectionDisabled(direction == .targetToEnglish)
            .textInputAutocapitalization(direction == .targetToEnglish ? .never : .sentences)

            Button {
                Task { await performTranslation() }
            } label: {
                HStack {
                    if isTranslating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "translate")
                    }
                    Text(isTranslating ? "Translating…" : "Translate")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canTranslate || isTranslating)
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Output card

    private func outputCard(_ result: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Translation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                confidenceBadge(result.confidence)
                Button {
                    UIPasteboard.general.string = result.translation
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(result.translation.isEmpty ? "(no translation)" : result.translation)
                .font(.title3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !result.notes.isEmpty {
                Text(result.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(recentSessions.prefix(10)) { session in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.inputText)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(session.outputText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(session.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    // MARK: - Confidence badge

    private func confidenceBadge(_ confidence: TranslationResult.Confidence) -> some View {
        let color: Color = switch confidence {
        case .high: .green
        case .medium: .orange
        case .low: .red
        }
        return Text(confidence.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Translation logic

    private func performTranslation() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isTranslating = true
        result = nil

        let entries = project.entries.map {
            TranslationService.LexiconEntry(
                english: $0.english,
                phonetic: $0.phonetic,
                category: $0.category,
                notes: $0.notes
            )
        }

        let translated = await TranslationService.shared.translate(
            text: text,
            direction: direction,
            languageName: project.languageName,
            entries: entries,
            apiKey: apiKey
        )

        result = translated
        isTranslating = false

        let session = TranslationSession(
            direction: direction.rawValue,
            inputText: text,
            outputText: translated.translation,
            confidence: translated.confidence.rawValue,
            project: project
        )
        context.insert(session)
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
    return TranslateView(project: project)
        .modelContainer(container)
}
