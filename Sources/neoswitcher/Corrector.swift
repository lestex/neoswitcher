import AppKit
import ApplicationServices
import Carbon
import NeoSwitcherCore

/// Performs corrections by posting synthetic events. Main thread only.
///
/// Sequence: (len+1) backspaces -> select target layout -> type corrected text + space as a
/// Unicode string (layout-independent, so it doesn't race the app noticing the layout change).
final class Corrector {
    private struct Applied {
        let originalLayout: Layout
        let originalText: String
        let correctedText: String
    }

    private let layouts: LayoutManager
    private let source: CGEventSource?
    private var applied: Applied?
    /// Delay between synthetic events; Electron apps drop events posted back-to-back.
    var eventDelayMicros: useconds_t = 1500

    private(set) var lastDescription: String?
    var onChange: (() -> Void)?

    init(layouts: LayoutManager) {
        self.layouts = layouts
        source = CGEventSource(stateID: .privateState)
        source?.userData = Constants.syntheticMarker
    }

    var hasPendingUndo: Bool { applied != nil }
    func clearUndo() { applied = nil }

    /// `terminator` is the key that ended the word (space, or return/tab if enabled in config).
    func correct(_ c: Correction, from current: Layout, terminator: UInt16 = KeyCode.space) {
        guard let target = layouts.layouts.first(where: { $0.id == c.targetID }) else { return }
        guard !IsSecureEventInputEnabled(), Permissions.accessibilityGranted(prompt: false) else {
            Log.decision("skipped: secure input or no Accessibility at post time")
            return
        }
        // original text + the terminator the user already typed (space, or a line break / tab)
        postBackspaces(c.original.count + 1)
        layouts.select(target)
        if terminator == KeyCode.space {
            postText(c.corrected + " ")
        } else {
            // Replay Return/Tab as real key events; a Unicode "\n" is not treated as Return everywhere.
            postText(c.corrected)
            let code = CGKeyCode(terminator == KeyCode.tab ? KeyCode.tab : KeyCode.returnKey)
            post(keyCode: code, down: true)
            post(keyCode: code, down: false)
        }
        applied = Applied(originalLayout: current, originalText: c.original, correctedText: c.corrected)
        lastDescription = "\(current.name) → \(target.name)"
        Log.decision("corrected \(current.id) -> \(target.id), len=\(c.original.count)")
        onChange?()
    }

    /// Called after the user pressed backspace right after a correction. The app already
    /// consumed that backspace (we only listen), which removed the trailing space.
    func undo() {
        guard let a = applied else { return }
        applied = nil
        guard !IsSecureEventInputEnabled(), Permissions.accessibilityGranted(prompt: false) else { return }
        postBackspaces(a.correctedText.count)
        layouts.select(a.originalLayout)
        postText(a.originalText)
        lastDescription = "undone"
        Log.decision("undone, restored \(a.originalLayout.id), len=\(a.originalText.count)")
        onChange?()
    }

    // MARK: - Posting

    private func postBackspaces(_ n: Int) {
        for _ in 0..<n {
            post(keyCode: CGKeyCode(KeyCode.delete), down: true)
            post(keyCode: CGKeyCode(KeyCode.delete), down: false)
        }
    }

    private func postText(_ text: String) {
        let utf16 = Array(text.utf16)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
            e.flags = []
            e.setIntegerValueField(.eventSourceUserData, value: Constants.syntheticMarker)
            e.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            e.post(tap: .cgSessionEventTap)
            usleep(eventDelayMicros)
        }
    }

    private func post(keyCode: CGKeyCode, down: Bool) {
        guard let e = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { return }
        e.flags = []
        e.setIntegerValueField(.eventSourceUserData, value: Constants.syntheticMarker)
        e.post(tap: .cgSessionEventTap)
        usleep(eventDelayMicros)
    }
}
