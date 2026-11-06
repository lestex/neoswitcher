import CoreGraphics
import Foundation
import Testing
@testable import NeoSwitcherCore

@Suite struct ModifiersTests {
    @Test func mapsEventFlags() {
        let m = Modifiers([CGEventFlags.maskShift, .maskAlphaShift, .maskCommand, .maskControl, .maskAlternate])
        #expect(m == [.shift, .caps, .command, .control, .option])
        #expect(Modifiers(CGEventFlags()) == [])
    }

    @Test func chordExcludesShiftAndCaps() {
        #expect(!Modifiers([.shift, .caps]).intersects(.chord))
        #expect(Modifiers([.shift, .command]).intersects(.chord))
    }
}

private extension Modifiers {
    func intersects(_ other: Modifiers) -> Bool { !isDisjoint(with: other) }
}

@Suite struct WordListLoadTests {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ns-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func loadsPerLanguageFiles() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "Привет 10\nмир 5\n".write(to: dir.appendingPathComponent("ru.txt"), atomically: true, encoding: .utf8)
        let list = WordList.load(languages: ["ru", "xx"], directory: dir)
        #expect(list.contains("привет", language: "ru"))
        #expect(list.contains("мир", language: "ru"))
        #expect(!list.hasLanguage("xx"))
    }

    @Test func englishFallsBackToSystemDictionary() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fallback = dir.appendingPathComponent("words")
        try "Hello\nworld\n".write(to: fallback, atomically: true, encoding: .utf8)
        let list = WordList.load(languages: ["en", "ru"], directory: dir, englishFallback: fallback.path)
        #expect(list.contains("hello", language: "en"))
        #expect(!list.hasLanguage("ru")) // no Russian fallback
    }
}

@Suite struct DetectorEdgeTests {
    private func layout(_ id: String, _ lang: String, _ out: String) -> Layout {
        Layout(id: id, name: id, language: lang) { _ in out }
    }

    @Test func ambiguousBetweenTwoLanguagesDoesNothing() {
        // Typed text unknown in "en"; both "ru" and "de" readings are dictionary words.
        let scorer = DictionaryScorer(list: WordList(words: ["en": [], "ru": ["aaa"], "de": ["aaa"]]))
        let d = Detector(scorer: scorer)
        let keys = [KeyStroke(keyCode: 0), KeyStroke(keyCode: 0), KeyStroke(keyCode: 0)]
        let c = d.detect(keys: keys, current: layout("us", "en", "qqq"),
                         alternatives: [layout("ru", "ru", "aaa"), layout("de", "de", "aaa")])
        #expect(c == nil)
    }

    @Test func coreTrimsPunctuationAndLowercases() {
        #expect(Detector.core("..Привет!?") == "привет")
        #expect(Detector.core("123") == "")
        #expect(Detector.core("it's") == "it's")
    }
}
