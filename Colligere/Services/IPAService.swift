import AVFoundation

@MainActor
final class IPAService {
    static let shared = IPAService()

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func playSymbol(_ sym: IPASymbol) {
        if let url = Bundle.main.url(forResource: sym.audioFileName, withExtension: "m4a", subdirectory: "IPAaudio") {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                audioPlayer = player
                audioPlayer?.play()
                return
            }
        }
        let utterance = AVSpeechUtterance(string: sym.description)
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }
}
