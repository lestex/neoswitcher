/// Result of feeding a key to the buffer.
public enum BufferEvent: Equatable {
    case none
    /// A word-ending key was pressed: the word (keys before it) is ready for evaluation.
    /// `terminator` is the key code that ended it (space by default).
    case wordEnded([KeyStroke], terminator: UInt16)
}

/// Word buffer state machine. Stores physical keys, never characters.
/// Not thread-safe: drive it from one thread (the main run loop).
public struct WordBuffer {
    public static let maxLength = 64

    public private(set) var keys: [KeyStroke] = []
    /// Set when the word exceeded `maxLength`; such words are never evaluated.
    private var overflowed = false

    /// Key codes that end a word and trigger evaluation. Default: space only. Return/Tab/Enter
    /// reset the buffer unless the user opts in via config.
    public let wordEndKeys: Set<UInt16>

    public init(wordEndKeys: Set<UInt16> = [KeyCode.space]) {
        self.wordEndKeys = wordEndKeys.isEmpty ? [KeyCode.space] : wordEndKeys
    }

    public var isEmpty: Bool { keys.isEmpty }

    public mutating func reset() {
        keys.removeAll(keepingCapacity: true)
        overflowed = false
    }

    @discardableResult
    public mutating func handleKeyDown(keyCode: UInt16, modifiers: Modifiers, isAutorepeat: Bool) -> BufferEvent {
        // Any Cmd/Ctrl/Option chord: not plain typing.
        if !modifiers.isDisjoint(with: .chord) {
            reset()
            return .none
        }

        if keyCode == KeyCode.delete {
            // Backspace is honoured even when auto-repeating.
            if !keys.isEmpty { keys.removeLast() }
            return .none
        }

        if isAutorepeat { return .none }

        if wordEndKeys.contains(keyCode) {
            defer { reset() }
            if overflowed || keys.isEmpty { return .none }
            return .wordEnded(keys, terminator: keyCode)
        }

        if KeyCode.wordKeys.contains(keyCode) {
            if keys.count >= Self.maxLength {
                overflowed = true
                return .none
            }
            keys.append(KeyStroke(keyCode: keyCode,
                                  shift: modifiers.contains(.shift),
                                  caps: modifiers.contains(.caps)))
            return .none
        }

        // return, tab, escape, arrows, home/end/pgup/pgdn, F-keys, keypad, anything else
        // that is not a configured word-end key.
        reset()
        return .none
    }
}
