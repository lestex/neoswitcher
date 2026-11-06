import CoreGraphics

/// A physical key press: layout-independent. Characters are derived later per layout.
public struct KeyStroke: Equatable {
    public var keyCode: UInt16
    public var shift: Bool
    public var caps: Bool

    public init(keyCode: UInt16, shift: Bool = false, caps: Bool = false) {
        self.keyCode = keyCode
        self.shift = shift
        self.caps = caps
    }
}

public struct Modifiers: OptionSet {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let shift   = Modifiers(rawValue: 1 << 0)
    public static let caps    = Modifiers(rawValue: 1 << 1)
    public static let command = Modifiers(rawValue: 1 << 2)
    public static let control = Modifiers(rawValue: 1 << 3)
    public static let option  = Modifiers(rawValue: 1 << 4)

    /// Chords that mean "not plain typing".
    public static let chord: Modifiers = [.command, .control, .option]

    public init(_ flags: CGEventFlags) {
        var m: Modifiers = []
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskAlphaShift) { m.insert(.caps) }
        if flags.contains(.maskCommand) { m.insert(.command) }
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        self = m
    }
}

/// ANSI/ISO virtual key codes (kVK_*) we care about.
public enum KeyCode {
    public static let space: UInt16 = 49
    public static let delete: UInt16 = 51   // backspace
    public static let returnKey: UInt16 = 36
    public static let keypadEnter: UInt16 = 76
    public static let tab: UInt16 = 48
    public static let escape: UInt16 = 53

    /// Keys that produce a character in a word: letters, number row, punctuation keys
    /// (including ISO section key 10).
    public static let wordKeys: Set<UInt16> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46,
        47, 50,
    ]
}
