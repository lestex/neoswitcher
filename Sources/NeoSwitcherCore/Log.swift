import Foundation

/// Decision-level logging. Typed content is only ever printed via `content(_:)`,
/// which is a no-op unless `--debug-content` was passed.
public enum Log {
    public static var debugContent = false
    public static var verbose = false

    public static func info(_ message: @autoclosure () -> String) {
        FileHandle.standardError.write(Data(("[neoswitcher] " + message() + "\n").utf8))
    }

    public static func decision(_ message: @autoclosure () -> String) {
        if verbose { info(message()) }
    }

    public static func content(_ message: @autoclosure () -> String) {
        if debugContent { info("(content) " + message()) }
    }
}

public enum Constants {
    /// Marker stored in `.eventSourceUserData` on every synthetic event we post ("NEOS").
    public static let syntheticMarker: Int64 = 0x4E45_4F53
}
