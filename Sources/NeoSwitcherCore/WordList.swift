import Foundation

/// Per-language word sets. Build once at startup (off the tap callback); lookups are O(1).
public struct WordList {
    public private(set) var words: [String: Set<String>] = [:]

    public init(words: [String: Set<String>] = [:]) { self.words = words }

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/neoswitcher", isDirectory: true)
    }

    public func contains(_ word: String, language: String) -> Bool {
        words[language]?.contains(word) ?? false
    }

    public func hasLanguage(_ language: String) -> Bool { !(words[language]?.isEmpty ?? true) }

    /// Parse "word" or "word count" lines: first whitespace-separated field, lowercased.
    public static func parse(_ text: String) -> Set<String> {
        var set = Set<String>()
        text.enumerateLines { line, _ in
            guard let first = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else { return }
            set.insert(first.lowercased())
        }
        return set
    }

    /// Load `<dir>/<lang>.txt` for each language; "en" falls back to /usr/share/dict/words.
    public static func load(languages: [String], directory: URL = defaultDirectory,
                            englishFallback: String = "/usr/share/dict/words") -> WordList {
        var result: [String: Set<String>] = [:]
        for lang in languages {
            let url = directory.appendingPathComponent("\(lang).txt")
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                result[lang] = parse(text)
            } else if lang == "en", let text = try? String(contentsOfFile: englishFallback, encoding: .utf8) {
                result[lang] = parse(text)
            }
        }
        return WordList(words: result)
    }
}
