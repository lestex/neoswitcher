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

    public init(scorer: LayoutScorer, minLength: Int = 3) {
        self.scorer = scorer
        self.minLength = minLength
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
        guard typedCore.count >= minLength else { return nil }
        // Valid in the current layout (including words valid in both) -> never switch.
        if scorer.isWord(typedCore, language: current.language) { return nil }

        var matches: [Correction] = []
        for alt in alternatives where alt.language != current.language {
            let text = alt.translate(keys)
            let c = Self.core(text)
            guard c.count >= minLength, scorer.isWord(c, language: alt.language) else { continue }
            matches.append(Correction(targetID: alt.id, targetLanguage: alt.language,
                                      original: typed, corrected: text))
        }
        // Ambiguous between several languages -> do nothing.
        return matches.count == 1 ? matches[0] : nil
    }
}
