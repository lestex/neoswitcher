import Testing
@testable import NeoSwitcherCore

// Fake ANSI QWERTY / ЙЦУКЕН layouts so detection tests run on any machine.
private let qwerty: [UInt16: Character] = [
    0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v", 11: "b",
    12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 31: "o", 32: "u", 34: "i", 35: "p",
    37: "l", 38: "j", 40: "k", 45: "n", 46: "m", 43: ",", 47: ".", 41: ";", 39: "'", 33: "[", 30: "]",
]
private let jcuken: [UInt16: Character] = [
    0: "ф", 1: "ы", 2: "в", 3: "а", 4: "р", 5: "п", 6: "я", 7: "ч", 8: "с", 9: "м", 11: "и",
    12: "й", 13: "ц", 14: "у", 15: "к", 16: "н", 17: "е", 31: "щ", 32: "г", 34: "ш", 35: "з",
    37: "д", 38: "о", 40: "л", 45: "т", 46: "ь", 43: "б", 47: "ю", 41: "ж", 39: "э", 33: "х", 30: "ъ",
]

private func fake(_ id: String, _ lang: String, _ map: [UInt16: Character]) -> Layout {
    Layout(id: id, name: id, language: lang) { k in
        let ch = map[k.keyCode].map(String.init) ?? ""
        return (k.shift || k.caps) ? ch.uppercased() : ch
    }
}
private let us = fake("us", "en", qwerty)
private let ru = fake("ru", "ru", jcuken)

private func keys(_ s: String, in map: [UInt16: Character]) -> [KeyStroke] {
    s.map { c in KeyStroke(keyCode: map.first { $0.value == c }!.key) }
}

private func detector(en: Set<String> = ["hello", "the", "she"], ruWords: Set<String> = ["привет", "белое", "для"]) -> Detector {
    Detector(scorer: DictionaryScorer(list: WordList(words: ["en": en, "ru": ruWords])))
}

@Suite struct DetectorTests {
    @Test func ghbdtnCorrectsToRussian() {
        let c = detector().detect(keys: keys("ghbdtn", in: qwerty), current: us, alternatives: [ru])
        #expect(c?.corrected == "привет")
        #expect(c?.targetID == "ru")
        #expect(c?.original == "ghbdtn")
    }

    @Test func helloInUSDoesNothing() {
        #expect(detector().detect(keys: keys("hello", in: qwerty), current: us, alternatives: [ru]) == nil)
    }

    @Test func russianTypedHelloCorrectsToEnglish() {
        let c = detector().detect(keys: keys("руддщ", in: jcuken), current: ru, alternatives: [us])
        #expect(c?.corrected == "hello")
        #expect(c?.targetID == "us")
    }

    @Test func shortWordsSkipped() {
        let d = detector(en: [], ruWords: ["да", "ру"])
        #expect(d.detect(keys: keys("lf", in: qwerty), current: us, alternatives: [ru]) == nil)
    }

    @Test func validInBothNeverSwitches() {
        // "she" is English; in RU keys it reads "ыру" - make that a Russian word too.
        let d = detector(en: ["she"], ruWords: ["ыру"])
        #expect(d.detect(keys: keys("she", in: qwerty), current: us, alternatives: [ru]) == nil)
    }

    @Test func unknownInBothDoesNothing() {
        #expect(detector().detect(keys: keys("qqq", in: qwerty), current: us, alternatives: [ru]) == nil)
    }

    @Test func punctuationKeysInCoreAndEdges() {
        // ",tkjt" -> "белое" (leading б comes from the comma key); in US core is "tkjt".
        let c = detector().detect(keys: keys(",tkjt", in: qwerty), current: us, alternatives: [ru])
        #expect(c?.corrected == "белое")
        // trailing punctuation is trimmed for lookup but preserved in the output
        let d = detector().detect(keys: keys("ghbdtn.", in: qwerty), current: us, alternatives: [ru])
        #expect(d == nil) // "привет" + "ю" is not a dictionary word: letter core "приветю"
    }

    @Test func caseIsPreservedButLookupIsLowercase() {
        var ks = keys("ghbdtn", in: qwerty)
        ks[0].shift = true
        #expect(detector().detect(keys: ks, current: us, alternatives: [ru])?.corrected == "Привет")
    }

    @Test func sameLanguageAlternativesIgnored() {
        let abc = fake("abc", "en", qwerty)
        #expect(detector().detect(keys: keys("ghbdtn", in: qwerty), current: us, alternatives: [abc]) == nil)
    }

    @Test func scorerIsSwappable() {
        struct Always: LayoutScorer { func isWord(_ core: String, language: String) -> Bool { language == "ru" } }
        let d = Detector(scorer: Always())
        #expect(d.detect(keys: keys("qqq", in: qwerty), current: us, alternatives: [ru])?.targetID == "ru")
    }

    @Test func wordListParsing() {
        let s = WordList.parse("Привет 12345\nдля\t99\n\nHELLO\n")
        #expect(s == ["привет", "для", "hello"])
    }
}

private let hasBoth: Bool = {
    let m = sharedLayoutManager
    return m.layouts.contains { $0.language == "en" } && m.layouts.contains { $0.language == "ru" }
}()

@Suite struct DetectorIntegrationTests {
    @Test(.enabled(if: hasBoth)) func realLayoutsGhbdtn() {
        let m = sharedLayoutManager
        let en = m.layouts.first { $0.language == "en" }!
        let c = detector().detect(keys: keys("ghbdtn", in: qwerty), current: en, alternatives: m.alternatives(to: en))
        #expect(c?.corrected == "привет")
    }
}
