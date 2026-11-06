import ApplicationServices
import CoreGraphics
import Foundation

enum Permissions {
    /// Accessibility: needed to post synthetic events.
    static func accessibilityGranted(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" // kAXTrustedCheckOptionPrompt
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// Input Monitoring: needed for the event tap.
    static func inputMonitoringGranted() -> Bool { CGPreflightListenEventAccess() }

    @discardableResult
    static func requestInputMonitoring() -> Bool { CGRequestListenEventAccess() }

    static func printInstructions(accessibility: Bool, inputMonitoring: Bool) {
        var lines = ["Missing permissions. Open System Settings > Privacy & Security and enable this app in:"]
        if !inputMonitoring { lines.append("  - Input Monitoring (needed to see keystrokes)") }
        if !accessibility { lines.append("  - Accessibility (needed to type the correction)") }
        lines.append("The menu bar icon shows a warning until both are granted; no relaunch is needed.")
        lines.forEach { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    }
}
