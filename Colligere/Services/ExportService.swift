import Foundation

enum ExportService {

    // MARK: - ZIP export

    static func createArchiveURL(for project: LanguageProject) throws -> URL {
        var files: [(name: String, data: Data)] = []

        files.append(("lexicon.json", try lexiconData(for: project)))

        let fm = FileManager.default
        for entry in project.entries {
            for recording in entry.recordings {
                guard let url = recording.fileURL,
                      fm.fileExists(atPath: url.path),
                      let data = try? Data(contentsOf: url) else { continue }
                let slug = entry.english
                    .prefix(30)
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "\\", with: "_")
                files.append(("audio/\(slug)_\(recording.id.uuidString).m4a", data))
            }
        }

        let zipData = buildZip(files: files)
        let safeName = project.languageName
            .replacingOccurrences(of: "/", with: "_")
            .prefix(60)
        let dest = fm.temporaryDirectory
            .appendingPathComponent("\(String(safeName))_\(Int(Date().timeIntervalSince1970)).zip")
        try zipData.write(to: dest)
        return dest
    }

    // MARK: - JSON import

    struct ImportedLexicon: Decodable {
        struct Entry: Decodable {
            let english: String
            let phonetic: String
            let category: String
            let notes: String
            let priority: Int
        }
        let languageName: String
        let entries: [Entry]
    }

    static func importLexicon(from url: URL) throws -> ImportedLexicon {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ImportedLexicon.self, from: data)
    }

    // MARK: - JSON helper (shared with SettingsView)

    static func lexiconData(for project: LanguageProject) throws -> Data {
        struct Entry: Encodable {
            let english, phonetic, category, notes: String
            let priority: Int
            let isCollected: Bool
            let recordingCount: Int
        }
        struct Export: Encodable {
            let languageName: String
            let exportedAt: String
            let entryCount: Int
            let entries: [Entry]
        }
        let entries = project.entries
            .sorted { $0.english < $1.english }
            .map { e in
                Entry(english: e.english, phonetic: e.phonetic, category: e.category,
                      notes: e.notes, priority: e.priority, isCollected: e.isCollected,
                      recordingCount: e.recordings.count)
            }
        let export = Export(
            languageName: project.languageName,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            entryCount: entries.count,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    // MARK: - Minimal ZIP writer (STORE, no compression)

    private static func buildZip(files: [(name: String, data: Data)]) -> Data {
        var zip = Data()
        var centralDir = Data()
        var localOffsets: [UInt32] = []

        for (name, fileData) in files {
            let nameBytes = Data(name.utf8)
            let checksum = crc32(fileData)
            let sz = UInt32(fileData.count)
            localOffsets.append(UInt32(zip.count))

            zip += le32(0x04034b50)         // local file header signature
            zip += le16(20)                 // version needed
            zip += le16(0)                  // flags
            zip += le16(0)                  // compression: STORE
            zip += le16(0) + le16(0)        // mod time + date
            zip += le32(checksum)
            zip += le32(sz) + le32(sz)      // compressed = uncompressed
            zip += le16(UInt16(nameBytes.count))
            zip += le16(0)                  // extra field length
            zip += nameBytes
            zip += fileData
        }

        let cdStart = UInt32(zip.count)

        for (i, (name, fileData)) in files.enumerated() {
            let nameBytes = Data(name.utf8)
            let checksum = crc32(fileData)
            let sz = UInt32(fileData.count)

            centralDir += le32(0x02014b50)  // central directory signature
            centralDir += le16(20)          // version made by
            centralDir += le16(20)          // version needed
            centralDir += le16(0)           // flags
            centralDir += le16(0)           // compression
            centralDir += le16(0) + le16(0) // mod time + date
            centralDir += le32(checksum)
            centralDir += le32(sz) + le32(sz)
            centralDir += le16(UInt16(nameBytes.count))
            centralDir += le16(0)           // extra field length
            centralDir += le16(0)           // comment length
            centralDir += le16(0)           // disk number start
            centralDir += le16(0)           // internal attributes
            centralDir += le32(0)           // external attributes
            centralDir += le32(localOffsets[i])
            centralDir += nameBytes
        }

        zip += centralDir
        zip += le32(0x06054b50)             // end of central directory
        zip += le16(0) + le16(0)            // disk numbers
        zip += le16(UInt16(files.count))
        zip += le16(UInt16(files.count))
        zip += le32(UInt32(centralDir.count))
        zip += le32(cdStart)
        zip += le16(0)                      // comment length

        return zip
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB88320 * (crc & 1))
            }
        }
        return ~crc
    }

    private static func le16(_ v: UInt16) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)])
    }

    private static func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
              UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
    }
}
