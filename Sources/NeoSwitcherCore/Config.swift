import Foundation

public struct Hotkey: Equatable {
    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ctrl+opt+cmd+P
    public static let defaultPause = Hotkey(keyCode: 35, modifiers: [.control, .option, .command])

    /// Exact match on the modifiers that matter (shift, ctrl, opt, cmd); caps lock is ignored.
    public func matches(keyCode: UInt16, modifiers mods: Modifiers) -> Bool {
        keyCode == self.keyCode && mods.subtracting(.caps) == modifiers
    }
}

public struct Config: Equatable {
    public static let defaultExcludedBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
    ]

    public var excludedBundleIDs: Set<String> = Config.defaultExcludedBundleIDs
    public var pauseHotkey: Hotkey = .defaultPause
    public var eventDelayMicros: UInt32 = 1500

    public init() {}

    public static var defaultURL: URL { WordList.defaultDirectory.appendingPathComponent("config.json") }

    /// File shape (all keys optional):
    /// { "excludedBundleIDs": ["..."], "pauseHotkey": {"keyCode": 35, "modifiers": ["ctrl","opt","cmd"]},
    ///   "eventDelayMicros": 1500 }
    /// `excludedBundleIDs` replaces the defaults entirely.
    public static func parse(_ data: Data) -> Config? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var c = Config()
        if let ids = obj["excludedBundleIDs"] as? [String] { c.excludedBundleIDs = Set(ids) }
        if let d = obj["eventDelayMicros"] as? Int, d >= 0 { c.eventDelayMicros = UInt32(d) }
        if let h = obj["pauseHotkey"] as? [String: Any], let code = h["keyCode"] as? Int,
           let names = h["modifiers"] as? [String] {
            var m: Modifiers = []
            for n in names {
                switch n.lowercased() {
                case "ctrl", "control": m.insert(.control)
                case "opt", "option", "alt": m.insert(.option)
                case "cmd", "command": m.insert(.command)
                case "shift": m.insert(.shift)
                default: return nil
                }
            }
            c.pauseHotkey = Hotkey(keyCode: UInt16(truncatingIfNeeded: code), modifiers: m)
        }
        return c
    }

    /// Missing file -> defaults; unreadable/invalid file -> defaults.
    public static func load(from url: URL = defaultURL) -> Config {
        guard let data = try? Data(contentsOf: url) else { return Config() }
        return parse(data) ?? Config()
    }
}
