import Foundation

/// Decides whether a lowercase letter core is a real word in a language.
/// Swap in an n-gram log-likelihood model here later (v2).
public protocol LayoutScorer {
    func isWord(_ core: String, language: String) -> Bool
}

public final class DictionaryScorer: LayoutScorer {
    public var list: WordList
    public init(list: WordList = WordList()) { self.list = list }
    public func isWord(_ core: String, language: String) -> Bool {
        list.contains(core, language: language)
    }
}

public struct Correction: Equatable {
    public let targetID: String
    public let targetLanguage: String
    /// What the user actually typed (in the current layout).
    public let original: String
    /// What it should have been (in the target layout).
    public let corrected: String

    public static func == (a: Correction, b: Correction) -> Bool {
        a.targetID == b.targetID && a.corrected == b.corrected && a.original == b.original
    }
}

public struct Detector {
    public var scorer: LayoutScorer
    public var minLength: Int
    /// Words shorter than `minLength` are too ambiguous for the (noisy) dictionaries,
    /// so they are corrected only when listed here, per language.
    public var shortWords: [String: Set<String>]

    public static let defaultShortWords: [String: Set<String>] = [
        "ru": ["я", "в", "и", "с", "к", "о", "у", "а",
               "да", "не", "на", "он", "ты", "мы", "вы", "но", "за", "по", "из", "от", "до",
               "то", "же", "ли", "бы", "ни", "ну", "ей", "им", "её", "их", "ко", "во", "со"],
    ]

    public init(scorer: LayoutScorer, minLength: Int = 3,
                shortWords: [String: Set<String>] = Detector.defaultShortWords) {
        self.scorer = scorer
        self.minLength = minLength
        self.shortWords = shortWords
    }

    private func accepts(_ core: String, language: String) -> Bool {
        if core.count >= minLength { return scorer.isWord(core, language: language) }
        return !core.isEmpty && shortWords[language]?.contains(core) == true
    }

    /// Letters-only core, lowercased: trims non-letters from both ends.
    public static func core(_ s: String) -> String {
        let scalars = Array(s.unicodeScalars)
        var start = 0, end = scalars.count
        while start < end, !CharacterSet.letters.contains(scalars[start]) { start += 1 }
        while end > start, !CharacterSet.letters.contains(scalars[end - 1]) { end -= 1 }
        var out = String.UnicodeScalarView()
        out.append(contentsOf: scalars[start..<end])
        return String(out).lowercased()
    }

    public func detect(keys: [KeyStroke], current: Layout, alternatives: [Layout]) -> Correction? {
        let typed = current.translate(keys)
        let typedCore = Self.core(typed)
        // Valid in the current layout (including words valid in both) -> never switch.
        if !typedCore.isEmpty, scorer.isWord(typedCore, language: current.language) { return nil }

        var matches: [Correction] = []
        for alt in alternatives where alt.language != current.language {
            let text = alt.translate(keys)
            let c = Self.core(text)
            guard accepts(c, language: alt.language) else { continue }
            matches.append(Correction(targetID: alt.id, targetLanguage: alt.language,
                                      original: typed, corrected: text))
        }
        // Ambiguous between several languages -> do nothing.
        return matches.count == 1 ? matches[0] : nil
    }
}
