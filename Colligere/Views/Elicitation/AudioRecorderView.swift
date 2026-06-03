import SwiftUI
import SwiftData
import AVFoundation

// MARK: - AudioRecorderService

@Observable
final class AudioRecorderService: NSObject {
    var isRecording = false
    var isPlaying = false
    var recordingLevel: Float = -60
    var playbackLevel: Float = -60
    var recordingDuration: Double = 0
    var playingID: UUID?
    var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var monitorTask: Task<Void, Never>?

    func startRecording(to url: URL) async {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            recordingDuration = 0
            errorMessage = nil
            startMonitoring()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() -> (url: URL, duration: Double)? {
        guard let recorder, isRecording else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        let url = recorder.url
        self.recorder = nil
        isRecording = false
        monitorTask?.cancel()
        monitorTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (url, duration)
    }

    func play(_ recording: AudioRecording) {
        stopPlayback()
        guard let url = recording.fileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Recording file not found."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.isMeteringEnabled = true
            player?.play()
            playingID = recording.id
            isPlaying = true
            errorMessage = nil
            startPlaybackMonitoring()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        playingID = nil
        playbackLevel = -60
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task {
            while isRecording && !Task.isCancelled {
                recorder?.updateMeters()
                recordingLevel = recorder?.averagePower(forChannel: 0) ?? -60
                recordingDuration = recorder?.currentTime ?? 0
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func startPlaybackMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task {
            while !Task.isCancelled {
                guard let p = player else { break }
                if !p.isPlaying {
                    isPlaying = false
                    playingID = nil
                    break
                }
                p.updateMeters()
                playbackLevel = p.averagePower(forChannel: 0)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}

// MARK: - AudioRecorderView

struct AudioRecorderView: View {
    @Bindable var entry: LexicalEntry
    let projectID: UUID

    @State private var service = AudioRecorderService()
    @State private var pendingSpeakerLabel = ""
    @State private var showPermissionAlert = false
    @State private var transcriptionSuggestion: String?
    @State private var isTranscribing = false
    @Environment(\.modelContext) private var context

    private var sortedRecordings: [AudioRecording] {
        entry.recordings.sorted { $0.recordedAt < $1.recordedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !entry.recordings.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedRecordings) { recording in
                        RecordingRow(
                            recording: recording,
                            isPlaying: service.playingID == recording.id,
                            level: service.playingID == recording.id ? service.playbackLevel : -60,
                            onPlay: { service.play(recording) },
                            onStop: { service.stopPlayback() },
                            onDelete: { deleteRecording(recording) }
                        )
                    }
                }
            }

            if service.isRecording {
                VStack(spacing: 6) {
                    LevelMeterView(level: service.recordingLevel, tint: .red)
                    Text(formatDuration(service.recordingDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                TextField("Speaker label (optional)", text: $pendingSpeakerLabel)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)

                recordButton
            }

            if isTranscribing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Transcribing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let suggestion = transcriptionSuggestion, !suggestion.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Heard (orthography — not IPA)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            transcriptionSuggestion = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            if let err = service.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable microphone access in Settings to record audio.")
        }
        .onDisappear {
            if service.isRecording { _ = service.stopRecording() }
            service.stopPlayback()
        }
    }

    private var recordButton: some View {
        Button {
            if service.isRecording {
                finishRecording()
            } else {
                Task { await requestAndRecord() }
            }
        } label: {
            Image(systemName: service.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(service.isRecording ? Color.red : Color.accentColor)
                .symbolEffect(.pulse, isActive: service.isRecording)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
    }

    private func requestAndRecord() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            showPermissionAlert = true
            return
        }
        let url = recordingURL()
        await service.startRecording(to: url)
    }

    private func finishRecording() {
        guard let result = service.stopRecording() else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let relativePath = result.url.path.replacingOccurrences(of: docs.path + "/", with: "")
        let recording = AudioRecording(
            relativeFilePath: relativePath,
            durationSeconds: result.duration,
            entry: entry
        )
        recording.speakerLabel = pendingSpeakerLabel.isEmpty ? nil : pendingSpeakerLabel
        context.insert(recording)
        entry.recordings.append(recording)
        entry.updatedAt = Date()
        pendingSpeakerLabel = ""

        guard SpeechService.isAvailable else { return }
        let fileURL = result.url
        Task {
            isTranscribing = true
            transcriptionSuggestion = nil
            if let text = try? await SpeechService.transcribe(fileAt: fileURL), !text.isEmpty {
                transcriptionSuggestion = text
            }
            isTranscribing = false
        }
    }

    private func deleteRecording(_ recording: AudioRecording) {
        if let url = recording.fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        if service.playingID == recording.id { service.stopPlayback() }
        context.delete(recording)
        entry.updatedAt = Date()
    }

    private func recordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs
            .appendingPathComponent(projectID.uuidString)
            .appendingPathComponent("audio")
            .appendingPathComponent("\(entry.id.uuidString)_\(UUID().uuidString).m4a")
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - RecordingRow

private struct RecordingRow: View {
    let recording: AudioRecording
    let isPlaying: Bool
    let level: Float
    let onPlay: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                isPlaying ? onStop() : onPlay()
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isPlaying ? Color.red : Color.accentColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                if let label = recording.speakerLabel, !label.isEmpty {
                    Text(label)
                        .font(.caption.weight(.medium))
                }
                if isPlaying {
                    LevelMeterView(level: level, tint: .accentColor)
                        .frame(height: 6)
                } else {
                    Text(formatDuration(recording.durationSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(recording.recordedAt.formatted(.dateTime.hour().minute()))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - LevelMeterView

struct LevelMeterView: View {
    let level: Float
    var tint: Color = .accentColor

    private var normalized: Double {
        Double(max(level + 60, 0) / 60).clamped(to: 0...1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: geo.size.width * normalized)
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.05), value: normalized)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
