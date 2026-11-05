import Carbon
import Foundation

/// Enumerates enabled keyboard layouts, tracks the current one, switches layouts.
/// Main-thread use only.
public final class LayoutManager {
    public private(set) var layouts: [Layout] = []
    private var observer: NSObjectProtocol?

    public init() {
        reload()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in self?.reload() }
    }

    deinit {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
    }

    public func reload() {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable: true,
        ]
        // includeAllInstalled = false -> enabled sources only.
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else {
            layouts = []
            return
        }
        layouts = list.compactMap(Layout.from(source:))
    }

    /// The currently selected keyboard layout (nil if it has no 'uchr', e.g. an input method).
    public func current() -> Layout? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let id = TIS.string(src, kTISPropertyInputSourceID) else { return nil }
        return layouts.first { $0.id == id }
    }

    /// Layouts a word typed in `current` could have been meant for: one per distinct language
    /// other than the current one (skips US vs ABC style duplicates).
    public func alternatives(to current: Layout) -> [Layout] {
        var seen: Set<String> = [current.language]
        var result: [Layout] = []
        for l in layouts where !seen.contains(l.language) {
            seen.insert(l.language)
            result.append(l)
        }
        return result
    }

    /// Must be called on the main thread.
    @discardableResult
    public func select(_ layout: Layout) -> Bool {
        guard let source = layout.source else { return false }
        return TISSelectInputSource(source) == noErr
    }
}
