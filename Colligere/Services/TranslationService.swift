import Foundation

// MARK: - Supporting Types

enum TranslationDirection: String, Sendable, CaseIterable, Identifiable {
    var id: Self { self }
    case englishToTarget = "en→target"
    case targetToEnglish = "target→en"

    var label: String {
        switch self {
        case .englishToTarget: "English → Language"
        case .targetToEnglish: "Language → English"
        }
    }
}

struct TranslationResult: Sendable {
    let translation: String
    let confidence: Confidence
    let notes: String
    let isOffline: Bool

    enum Confidence: String, Sendable {
        case low, medium, high
        var label: String { rawValue.capitalized }
    }
}

enum TranslationError: LocalizedError {
    case apiError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): "API Error: \(msg)"
        case .parseError(let msg): "Response parse error: \(msg)"
        }
    }
}

// MARK: - TranslationService

actor TranslationService {
    static let shared = TranslationService()

    private static let anthropicModel = "claude-sonnet-4-20250514"

    struct LexiconEntry: Sendable {
        let english: String
        let phonetic: String
        let category: String
        let notes: String
    }

    // MARK: - Public entry point

    func translate(
        text: String,
        direction: TranslationDirection,
        languageName: String,
        entries: [LexiconEntry],
        apiKey: String?
    ) async -> TranslationResult {
        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            return translateOffline(text: text, direction: direction, entries: entries)
        }
        do {
            let systemPrompt = buildSystemPrompt(languageName: languageName, entries: entries)
            return try await translateCloud(
                text: text,
                direction: direction,
                languageName: languageName,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        } catch {
            var result = translateOffline(text: text, direction: direction, entries: entries)
            result = TranslationResult(
                translation: result.translation,
                confidence: result.confidence,
                notes: (result.notes.isEmpty ? "" : result.notes + "\n") + "Cloud unavailable: \(error.localizedDescription)",
                isOffline: true
            )
            return result
        }
    }

    // MARK: - Cloud inference (Anthropic)

    func translateCloud(
        text: String,
        direction: TranslationDirection,
        languageName: String,
        systemPrompt: String,
        apiKey: String
    ) async throws -> TranslationResult {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey.trimmingCharacters(in: .whitespaces), forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let dirLabel = direction == .englishToTarget
            ? "English → \(languageName)"
            : "\(languageName) → English"

        let userMessage = """
        Translate the following (\(dirLabel)):
        \(text)

        Respond ONLY with a JSON object (no markdown, no explanation):
        {"translation": "...", "confidence": "low|medium|high", "notes": "..."}
        """

        let body: [String: Any] = [
            "model": Self.anthropicModel,
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let errMsg = (try? JSONDecoder().decode(AnthropicErrorBody.self, from: data))?.error.message
                ?? "HTTP \(http.statusCode)"
            throw TranslationError.apiError(errMsg)
        }

        let apiResp = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = apiResp.content.first(where: { $0.type == "text" })?.text else {
            throw TranslationError.parseError("Empty API response")
        }

        let jsonStr = extractJSON(from: text)
        guard let jsonData = jsonStr.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(TranslationJSON.self, from: jsonData) else {
            throw TranslationError.parseError("Could not decode translation JSON from: \(text)")
        }

        let confidence: TranslationResult.Confidence
        switch parsed.confidence.lowercased() {
        case "high": confidence = .high
        case "medium": confidence = .medium
        default: confidence = .low
        }

        return TranslationResult(
            translation: parsed.translation,
            confidence: confidence,
            notes: parsed.notes,
            isOffline: false
        )
    }

    // MARK: - Offline lookup

    func translateOffline(
        text: String,
        direction: TranslationDirection,
        entries: [LexiconEntry]
    ) -> TranslationResult {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else {
            return TranslationResult(translation: "", confidence: .low, notes: "", isOffline: true)
        }
        switch direction {
        case .englishToTarget: return lookupEnglishToTarget(query: query, entries: entries)
        case .targetToEnglish: return lookupTargetToEnglish(query: query, entries: entries)
        }
    }

    private func lookupEnglishToTarget(query: String, entries: [LexiconEntry]) -> TranslationResult {
        if let match = entries.first(where: { $0.english.lowercased() == query }),
           !match.phonetic.isEmpty {
            return TranslationResult(translation: match.phonetic, confidence: .high, notes: "", isOffline: true)
        }
        if let match = entries.first(where: { $0.english.lowercased().hasPrefix(query) }),
           !match.phonetic.isEmpty {
            return TranslationResult(translation: match.phonetic, confidence: .medium, notes: "Approximate match for '\(match.english)'", isOffline: true)
        }
        let tokens = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if tokens.count > 1 {
            var parts: [String] = []
            var hits = 0
            for token in tokens {
                if let m = entries.first(where: { $0.english.lowercased() == token }), !m.phonetic.isEmpty {
                    parts.append(m.phonetic); hits += 1
                } else {
                    parts.append("[?\(token)]")
                }
            }
            let pct = Double(hits) / Double(tokens.count)
            let conf: TranslationResult.Confidence = pct >= 0.8 ? .high : pct >= 0.5 ? .medium : .low
            return TranslationResult(
                translation: parts.joined(separator: " "),
                confidence: conf,
                notes: hits < tokens.count ? "Some words not in lexicon. Add API key for cloud inference." : "",
                isOffline: true
            )
        }
        return TranslationResult(translation: "[UNKNOWN]", confidence: .low, notes: "Not in lexicon. Add API key for cloud inference.", isOffline: true)
    }

    private func lookupTargetToEnglish(query: String, entries: [LexiconEntry]) -> TranslationResult {
        if let match = entries.first(where: { $0.phonetic.lowercased() == query }) {
            return TranslationResult(translation: match.english, confidence: .high, notes: "", isOffline: true)
        }
        if let match = entries.first(where: { $0.phonetic.lowercased().hasPrefix(query) }) {
            return TranslationResult(translation: match.english, confidence: .medium, notes: "Approximate match", isOffline: true)
        }
        return TranslationResult(translation: "[UNKNOWN]", confidence: .low, notes: "Not in lexicon. Add API key for cloud inference.", isOffline: true)
    }

    // MARK: - System prompt builder

    func buildSystemPrompt(languageName: String, entries: [LexiconEntry]) -> String {
        let collected = entries.filter { !$0.phonetic.isEmpty }
        let byCategory = Dictionary(grouping: collected) { $0.category }

        var lines = [
            "You are a translation assistant for a field linguistics documentation project.",
            "The user is documenting an undocumented language called \"\(languageName)\".",
            "",
            "IMPORTANT INSTRUCTIONS:",
            "- Translate as faithfully as possible using the provided lexicon.",
            "- If a word is unknown, use the closest semantic equivalent and flag it.",
            "- Preserve grammatical structures observed in sentence frames.",
            "- Return ONLY a JSON object: { \"translation\": \"...\", \"confidence\": \"low|medium|high\", \"notes\": \"...\" }",
            "- Flag any words approximated or untranslatable. Use [UNKNOWN] for missing segments.",
            "",
            "LEXICON (\(collected.count) entries):"
        ]

        let order = ["Sentence Frames","Pronouns","Core Verbs","Swadesh","Leipzig-Jakarta",
                     "Numbers","Spatial & Temporal","Social & Kinship","Descriptors","Colors"]
        for cat in order {
            guard let items = byCategory[cat], !items.isEmpty else { continue }
            lines += ["", "[Category: \(cat)]"]
            for item in items.sorted(by: { $0.english < $1.english }) {
                lines.append("\(item.english) → \(item.phonetic)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private func extractJSON(from text: String) -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return text }
        return String(text[start...end])
    }
}

// MARK: - Decodable response models (private)

nonisolated private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

nonisolated private struct AnthropicErrorBody: Decodable {
    let error: ErrorDetail
    struct ErrorDetail: Decodable {
        let message: String
    }
}

nonisolated private struct TranslationJSON: Decodable {
    let translation: String
    let confidence: String
    let notes: String
}
