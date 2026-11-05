import AppKit
import CoreGraphics
import NeoSwitcherCore

/// Listen-only session event tap. The callback runs on the main run loop, so all
/// state touched from it is main-thread only. It must stay cheap and never block.
final class EventTap {
    /// Called for each real (non-synthetic) key-down. Return value ignored.
    var onKeyDown: ((_ keyCode: UInt16, _ modifiers: Modifiers, _ isAutorepeat: Bool) -> Void)?
    /// Called for any mouse button press.
    var onMouseDown: (() -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isInstalled: Bool { tap != nil }

    func install() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = src
        return true
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            Log.info("event tap was disabled by the system; re-enabled")
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            onMouseDown?()
        case .keyDown:
            // Ignore our own synthetic events.
            if event.getIntegerValueField(.eventSourceUserData) == Constants.syntheticMarker { return }
            let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            let auto = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            onKeyDown?(code, Modifiers(event.flags), auto)
        default:
            break
        }
    }
}

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let refcon {
        Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
