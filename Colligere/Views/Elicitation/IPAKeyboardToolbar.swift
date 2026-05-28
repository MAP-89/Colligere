import SwiftUI

// MARK: - IPASymbol

struct IPASymbol: Identifiable {
    var id: String { "\(category)|\(description)" }
    let symbol: String
    let displaySymbol: String
    let category: String
    let description: String
    let example: String

    var audioFileName: String {
        symbol.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: "_")
    }

    init(_ symbol: String, category: String, description: String, example: String) {
        self.symbol = symbol
        self.displaySymbol = category == "Diacritics" ? "◌" + symbol : symbol
        self.category = category
        self.description = description
        self.example = example
    }

    static let categories = [
        "Vowels", "Plosives", "Nasals", "Fricatives",
        "Approx.", "Trills/Taps", "Affricates", "Diacritics", "Tones"
    ]

    static func symbols(for category: String) -> [IPASymbol] {
        all.filter { $0.category == category }
    }

    static let all: [IPASymbol] = [
        // Vowels
        IPASymbol("i",  category: "Vowels", description: "Close front unrounded vowel", example: "as in 'see'"),
        IPASymbol("y",  category: "Vowels", description: "Close front rounded vowel", example: "as in French 'lune'"),
        IPASymbol("ɨ",  category: "Vowels", description: "Close central unrounded vowel", example: "as in Russian ты"),
        IPASymbol("ʉ",  category: "Vowels", description: "Close central rounded vowel", example: "as in Norwegian hus"),
        IPASymbol("ɯ",  category: "Vowels", description: "Close back unrounded vowel", example: "as in Turkish kız"),
        IPASymbol("u",  category: "Vowels", description: "Close back rounded vowel", example: "as in 'food'"),
        IPASymbol("ɪ",  category: "Vowels", description: "Near-close front unrounded vowel", example: "as in 'bit'"),
        IPASymbol("ʏ",  category: "Vowels", description: "Near-close front rounded vowel", example: "as in German hübsch"),
        IPASymbol("ʊ",  category: "Vowels", description: "Near-close back rounded vowel", example: "as in 'foot'"),
        IPASymbol("e",  category: "Vowels", description: "Close-mid front unrounded vowel", example: "as in French été"),
        IPASymbol("ø",  category: "Vowels", description: "Close-mid front rounded vowel", example: "as in French feu"),
        IPASymbol("ɘ",  category: "Vowels", description: "Close-mid central unrounded vowel", example: "rare"),
        IPASymbol("ɵ",  category: "Vowels", description: "Close-mid central rounded vowel", example: "as in Swedish full"),
        IPASymbol("ɤ",  category: "Vowels", description: "Close-mid back unrounded vowel", example: "as in Korean 으"),
        IPASymbol("o",  category: "Vowels", description: "Close-mid back rounded vowel", example: "as in 'bone'"),
        IPASymbol("e̞",  category: "Vowels", description: "Mid front unrounded vowel", example: "as in Spanish mesa"),
        IPASymbol("ə",  category: "Vowels", description: "Mid central vowel, schwa", example: "as in 'about'"),
        IPASymbol("ɛ",  category: "Vowels", description: "Open-mid front unrounded vowel", example: "as in 'bed'"),
        IPASymbol("œ",  category: "Vowels", description: "Open-mid front rounded vowel", example: "as in French peur"),
        IPASymbol("ɜ",  category: "Vowels", description: "Open-mid central unrounded vowel", example: "as in 'bird'"),
        IPASymbol("ɞ",  category: "Vowels", description: "Open-mid central rounded vowel", example: "rare"),
        IPASymbol("ʌ",  category: "Vowels", description: "Open-mid back unrounded vowel", example: "as in 'cup'"),
        IPASymbol("ɔ",  category: "Vowels", description: "Open-mid back rounded vowel", example: "as in 'thought'"),
        IPASymbol("æ",  category: "Vowels", description: "Near-open front unrounded vowel", example: "as in 'cat'"),
        IPASymbol("a",  category: "Vowels", description: "Open front unrounded vowel", example: "as in 'father'"),
        IPASymbol("ɶ",  category: "Vowels", description: "Open front rounded vowel", example: "rare"),
        IPASymbol("ä",  category: "Vowels", description: "Open central unrounded vowel", example: "centralized a"),
        IPASymbol("ɑ",  category: "Vowels", description: "Open back unrounded vowel", example: "as in British father"),
        IPASymbol("ɒ",  category: "Vowels", description: "Open back rounded vowel", example: "as in British lot"),

        // Plosives
        IPASymbol("p",  category: "Plosives", description: "Voiceless bilabial plosive", example: "as in 'pat'"),
        IPASymbol("b",  category: "Plosives", description: "Voiced bilabial plosive", example: "as in 'bat'"),
        IPASymbol("t",  category: "Plosives", description: "Voiceless alveolar plosive", example: "as in 'tap'"),
        IPASymbol("d",  category: "Plosives", description: "Voiced alveolar plosive", example: "as in 'dip'"),
        IPASymbol("ʈ",  category: "Plosives", description: "Voiceless retroflex plosive", example: "as in Hindi ट"),
        IPASymbol("ɖ",  category: "Plosives", description: "Voiced retroflex plosive", example: "as in Hindi ड"),
        IPASymbol("c",  category: "Plosives", description: "Voiceless palatal plosive", example: "as in Hungarian tyúk"),
        IPASymbol("ɟ",  category: "Plosives", description: "Voiced palatal plosive", example: "as in Hungarian gyár"),
        IPASymbol("k",  category: "Plosives", description: "Voiceless velar plosive", example: "as in 'kit'"),
        IPASymbol("ɡ",  category: "Plosives", description: "Voiced velar plosive", example: "as in 'get'"),
        IPASymbol("q",  category: "Plosives", description: "Voiceless uvular plosive", example: "as in Arabic ق"),
        IPASymbol("ɢ",  category: "Plosives", description: "Voiced uvular plosive", example: "rare"),
        IPASymbol("ʡ",  category: "Plosives", description: "Epiglottal plosive", example: "rare"),
        IPASymbol("ʔ",  category: "Plosives", description: "Glottal stop", example: "as in uh-oh"),

        // Nasals
        IPASymbol("m",  category: "Nasals", description: "Voiced bilabial nasal", example: "as in 'mat'"),
        IPASymbol("ɱ",  category: "Nasals", description: "Voiced labiodental nasal", example: "before f in symphony"),
        IPASymbol("n",  category: "Nasals", description: "Voiced alveolar nasal", example: "as in 'no'"),
        IPASymbol("ɳ",  category: "Nasals", description: "Voiced retroflex nasal", example: "as in Hindi ण"),
        IPASymbol("ɲ",  category: "Nasals", description: "Voiced palatal nasal", example: "as in Spanish ñ"),
        IPASymbol("ŋ",  category: "Nasals", description: "Voiced velar nasal", example: "as in 'sing'"),
        IPASymbol("ɴ",  category: "Nasals", description: "Voiced uvular nasal", example: "as in some Japanese dialects"),

        // Fricatives
        IPASymbol("ɸ",  category: "Fricatives", description: "Voiceless bilabial fricative", example: "as in Japanese fu"),
        IPASymbol("β",  category: "Fricatives", description: "Voiced bilabial fricative", example: "as in Spanish lave"),
        IPASymbol("f",  category: "Fricatives", description: "Voiceless labiodental fricative", example: "as in 'fat'"),
        IPASymbol("v",  category: "Fricatives", description: "Voiced labiodental fricative", example: "as in 'vat'"),
        IPASymbol("θ",  category: "Fricatives", description: "Voiceless dental fricative", example: "as in 'thin'"),
        IPASymbol("ð",  category: "Fricatives", description: "Voiced dental fricative", example: "as in 'this'"),
        IPASymbol("s",  category: "Fricatives", description: "Voiceless alveolar fricative", example: "as in 'sat'"),
        IPASymbol("z",  category: "Fricatives", description: "Voiced alveolar fricative", example: "as in 'zap'"),
        IPASymbol("ʃ",  category: "Fricatives", description: "Voiceless postalveolar fricative", example: "as in 'ship'"),
        IPASymbol("ʒ",  category: "Fricatives", description: "Voiced postalveolar fricative", example: "as in 'measure'"),
        IPASymbol("ʂ",  category: "Fricatives", description: "Voiceless retroflex fricative", example: "as in Mandarin sh"),
        IPASymbol("ʐ",  category: "Fricatives", description: "Voiced retroflex fricative", example: "as in Mandarin r"),
        IPASymbol("ç",  category: "Fricatives", description: "Voiceless palatal fricative", example: "as in German ich"),
        IPASymbol("ʝ",  category: "Fricatives", description: "Voiced palatal fricative", example: "as in Spanish yo"),
        IPASymbol("x",  category: "Fricatives", description: "Voiceless velar fricative", example: "as in Scottish loch"),
        IPASymbol("ɣ",  category: "Fricatives", description: "Voiced velar fricative", example: "as in Greek γ"),
        IPASymbol("χ",  category: "Fricatives", description: "Voiceless uvular fricative", example: "as in Arabic خ"),
        IPASymbol("ʁ",  category: "Fricatives", description: "Voiced uvular fricative", example: "as in French r"),
        IPASymbol("ħ",  category: "Fricatives", description: "Voiceless pharyngeal fricative", example: "as in Arabic ح"),
        IPASymbol("ʕ",  category: "Fricatives", description: "Voiced pharyngeal fricative", example: "as in Arabic ع"),
        IPASymbol("h",  category: "Fricatives", description: "Voiceless glottal fricative", example: "as in 'hat'"),
        IPASymbol("ɦ",  category: "Fricatives", description: "Voiced glottal fricative", example: "as in Czech had"),

        // Approximants
        IPASymbol("ʋ",  category: "Approx.", description: "Voiced labiodental approximant", example: "as in Dutch wat"),
        IPASymbol("ɹ",  category: "Approx.", description: "Voiced alveolar approximant", example: "as in English red"),
        IPASymbol("ɻ",  category: "Approx.", description: "Voiced retroflex approximant", example: "as in Mandarin r"),
        IPASymbol("j",  category: "Approx.", description: "Voiced palatal approximant", example: "as in 'yes'"),
        IPASymbol("ɰ",  category: "Approx.", description: "Voiced velar approximant", example: "as in Korean 의"),
        IPASymbol("l",  category: "Approx.", description: "Voiced alveolar lateral approximant", example: "as in 'let'"),
        IPASymbol("ɭ",  category: "Approx.", description: "Voiced retroflex lateral approximant", example: "as in Tamil ழ"),
        IPASymbol("ʎ",  category: "Approx.", description: "Voiced palatal lateral approximant", example: "as in Italian gli"),
        IPASymbol("ʟ",  category: "Approx.", description: "Voiced velar lateral approximant", example: "rare"),

        // Trills / Taps
        IPASymbol("ʙ",  category: "Trills/Taps", description: "Voiced bilabial trill", example: "rare"),
        IPASymbol("r",  category: "Trills/Taps", description: "Voiced alveolar trill", example: "as in Spanish perro"),
        IPASymbol("ʀ",  category: "Trills/Taps", description: "Voiced uvular trill", example: "as in some French dialects"),
        IPASymbol("ɾ",  category: "Trills/Taps", description: "Voiced alveolar tap", example: "as in Spanish pero"),
        IPASymbol("ɽ",  category: "Trills/Taps", description: "Voiced retroflex tap", example: "as in Hindi ड़"),
        IPASymbol("ɺ",  category: "Trills/Taps", description: "Voiced alveolar lateral flap", example: "as in Japanese r"),

        // Affricates
        IPASymbol("t͡s", category: "Affricates", description: "Voiceless alveolar affricate", example: "as in 'cats'"),
        IPASymbol("d͡z", category: "Affricates", description: "Voiced alveolar affricate", example: "as in 'adze'"),
        IPASymbol("t͡ʃ", category: "Affricates", description: "Voiceless postalveolar affricate", example: "as in 'church'"),
        IPASymbol("d͡ʒ", category: "Affricates", description: "Voiced postalveolar affricate", example: "as in 'judge'"),
        IPASymbol("t͡ɕ", category: "Affricates", description: "Voiceless alveolo-palatal affricate", example: "as in Mandarin j"),
        IPASymbol("d͡ʑ", category: "Affricates", description: "Voiced alveolo-palatal affricate", example: "as in Polish dź"),

        // Diacritics (combining — displayed as ◌ + char)
        IPASymbol("\u{0325}", category: "Diacritics", description: "Voiceless diacritic", example: "e.g. n̥"),
        IPASymbol("\u{0324}", category: "Diacritics", description: "Breathy voice diacritic", example: "e.g. b̤"),
        IPASymbol("\u{0330}", category: "Diacritics", description: "Creaky voice diacritic", example: "e.g. b̰"),
        IPASymbol("\u{033A}", category: "Diacritics", description: "Apical diacritic", example: "e.g. t̺"),
        IPASymbol("\u{033B}", category: "Diacritics", description: "Laminal diacritic", example: "e.g. t̻"),
        IPASymbol("\u{033C}", category: "Diacritics", description: "Linguolabial diacritic", example: "e.g. t̼"),
        IPASymbol("\u{0339}", category: "Diacritics", description: "More rounded diacritic", example: "e.g. ɔ̹"),
        IPASymbol("\u{031C}", category: "Diacritics", description: "Less rounded diacritic", example: "e.g. ɔ̜"),
        IPASymbol("\u{031F}", category: "Diacritics", description: "Advanced diacritic", example: "e.g. u̟"),
        IPASymbol("\u{0320}", category: "Diacritics", description: "Retracted diacritic", example: "e.g. e̠"),
        IPASymbol("\u{0308}", category: "Diacritics", description: "Centralized diacritic", example: "e.g. ë"),
        IPASymbol("\u{033D}", category: "Diacritics", description: "Mid-centralized diacritic", example: "e.g. e̽"),
        IPASymbol("\u{0318}", category: "Diacritics", description: "Advanced tongue root diacritic", example: "e.g. e̘"),
        IPASymbol("\u{0319}", category: "Diacritics", description: "Retracted tongue root diacritic", example: "e.g. e̙"),
        IPASymbol("\u{031A}", category: "Diacritics", description: "No audible release diacritic", example: "e.g. p̚"),
        IPASymbol("\u{031B}", category: "Diacritics", description: "Raised larynx diacritic", example: "e.g. t̛"),
        IPASymbol("\u{031D}", category: "Diacritics", description: "Raised diacritic", example: "e.g. e̝"),
        IPASymbol("\u{031E}", category: "Diacritics", description: "Lowered diacritic", example: "e.g. e̞"),
        IPASymbol("\u{0329}", category: "Diacritics", description: "Syllabic diacritic", example: "e.g. n̩"),
        IPASymbol("\u{032F}", category: "Diacritics", description: "Non-syllabic diacritic", example: "e.g. e̯"),
        IPASymbol("\u{035C}", category: "Diacritics", description: "Co-articulation diacritic below", example: "links two segments"),
        IPASymbol("\u{0361}", category: "Diacritics", description: "Co-articulation diacritic above", example: "links two segments"),
        IPASymbol("ˈ",       category: "Diacritics", description: "Primary stress mark", example: "before stressed syllable"),
        IPASymbol("ˌ",       category: "Diacritics", description: "Secondary stress mark", example: "before secondary stress"),
        IPASymbol("ː",       category: "Diacritics", description: "Long vowel mark", example: "after long vowel"),
        IPASymbol("ˑ",       category: "Diacritics", description: "Half-long mark", example: "after half-long vowel"),

        // Tones
        IPASymbol("˥",  category: "Tones", description: "Extra high level tone", example: "tone level 5"),
        IPASymbol("˦",  category: "Tones", description: "High level tone", example: "tone level 4"),
        IPASymbol("˧",  category: "Tones", description: "Mid level tone", example: "tone level 3"),
        IPASymbol("˨",  category: "Tones", description: "Low level tone", example: "tone level 2"),
        IPASymbol("˩",  category: "Tones", description: "Extra low level tone", example: "tone level 1"),
        IPASymbol("↗",  category: "Tones", description: "Global rise tone", example: "rising intonation"),
        IPASymbol("↘",  category: "Tones", description: "Global fall tone", example: "falling intonation"),
        IPASymbol("˥˩", category: "Tones", description: "High falling contour tone", example: "5 to 1 falling"),
        IPASymbol("˩˥", category: "Tones", description: "Low rising contour tone", example: "1 to 5 rising"),
        IPASymbol("˧˥", category: "Tones", description: "Mid rising contour tone", example: "3 to 5 rising"),
        IPASymbol("˧˩", category: "Tones", description: "Mid falling contour tone", example: "3 to 1 falling"),
    ]
}

// MARK: - IPAKeyboardToolbar

struct IPAKeyboardToolbar: View {
    @Binding var text: String
    var onDone: (() -> Void)? = nil

    @State private var selectedCategory = "Vowels"
    @State private var hintLabel = ""
    @State private var isShowingHint = false

    var body: some View {
        VStack(spacing: 0) {
            if isShowingHint {
                Text(hintLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
            categoryRow
            Divider()
            symbolRow
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.15), value: isShowingHint)
        .animation(.easeInOut(duration: 0.1), value: selectedCategory)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(IPASymbol.categories, id: \.self) { cat in
                    Button(cat) { selectedCategory = cat }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedCategory == cat ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }

    private var symbolRow: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(IPASymbol.symbols(for: selectedCategory)) { sym in
                        symbolButton(sym)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }

            Divider().frame(height: 32)

            HStack(spacing: 4) {
                Button {
                    if !text.isEmpty { text.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                        .frame(width: 36, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                if let onDone {
                    Button("Done") { onDone() }
                        .font(.caption.weight(.semibold))
                        .frame(height: 32)
                        .padding(.horizontal, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func symbolButton(_ sym: IPASymbol) -> some View {
        Button {
            text.append(sym.symbol)
            showHint(sym)
        } label: {
            Text(sym.displaySymbol)
                .font(.system(size: 18))
                .frame(minWidth: 36, minHeight: 32)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                IPAService.shared.playSymbol(sym)
            }
        )
    }

    private func showHint(_ sym: IPASymbol) {
        hintLabel = "\(sym.displaySymbol)  \(sym.description) — \(sym.example)"
        isShowingHint = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            isShowingHint = false
        }
    }
}

