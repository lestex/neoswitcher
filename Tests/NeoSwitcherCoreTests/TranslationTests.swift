import Testing
@testable import NeoSwitcherCore

private func enabled(_ language: String) -> Layout? {
    sharedLayoutManager.layouts.first { $0.language == language }
}
private let hasEn = enabled("en") != nil
private let hasRu = enabled("ru") != nil

private func keys(_ codes: [UInt16], shift: Bool = false, caps: Bool = false) -> [KeyStroke] {
    codes.map { KeyStroke(keyCode: $0, shift: shift, caps: caps) }
}
private let ghbdtn: [UInt16] = [5, 4, 11, 2, 17, 45]

// Real 'uchr' translation; skipped when the layout isn't enabled on this machine.
@Suite struct TranslationTests {
    @Test(.enabled(if: hasEn)) func english() {
        let en = enabled("en")!
        #expect(en.translate(keys(ghbdtn)) == "ghbdtn")
        #expect(en.translate(keys(ghbdtn, shift: true)) == "GHBDTN")
        #expect(en.translate(keys(ghbdtn, caps: true)) == "GHBDTN")
        #expect(en.translate(keys(ghbdtn, shift: true, caps: true)) == "GHBDTN")
    }

    @Test(.enabled(if: hasRu)) func russian() {
        let ru = enabled("ru")!
        #expect(ru.translate(keys(ghbdtn)) == "привет")
        #expect(ru.translate(keys(ghbdtn, shift: true)) == "ПРИВЕТ")
        #expect(ru.translate(keys(ghbdtn, caps: true)) == "ПРИВЕТ")
    }

    @Test(.enabled(if: hasRu)) func russianPunctuationKeys() {
        // , . ; ' [ ]  (the grave key -> ё is omitted: its keycode mapping varies with the
        // hardware keyboard type reported by LMGetKbdType, which is exactly why we pass it through)
        #expect(enabled("ru")!.translate(keys([43, 47, 41, 39, 33, 30])) == "бюжэхъ")
    }

    @Test(.enabled(if: hasEn)) func alternativesSkipSameLanguage() {
        let m = sharedLayoutManager
        let cur = m.layouts.first { $0.language == "en" }!
        let alts = m.alternatives(to: cur)
        #expect(!alts.contains { $0.language == "en" })
        #expect(Set(alts.map(\.language)).count == alts.count)
    }
}
