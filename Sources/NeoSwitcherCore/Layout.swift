import Carbon
import Foundation

/// A keyboard layout we can translate key codes with.
public final class Layout {
    public let id: String
    public let name: String
    /// Primary language code, e.g. "en", "ru".
    public let language: String
    let source: TISInputSource?
    private let translateKey: (KeyStroke) -> String

    /// Test/utility initializer with an arbitrary translation function.
    public init(id: String, name: String, language: String,
                source: TISInputSource? = nil,
                translateKey: @escaping (KeyStroke) -> String) {
        self.id = id
        self.name = name
        self.language = language
        self.source = source
        self.translateKey = translateKey
    }

    public func translate(_ keys: [KeyStroke]) -> String {
        keys.map(translateKey).joined()
    }

    /// Build from a TIS source; nil for sources without 'uchr' data (input methods).
    static func from(source: TISInputSource) -> Layout? {
        guard let id = TIS.string(source, kTISPropertyInputSourceID),
              let dataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let cfData = Unmanaged<CFData>.fromOpaque(dataRef).takeUnretainedValue()
        let uchr = cfData as Data
        let name = TIS.string(source, kTISPropertyLocalizedName) ?? id
        let langs = TIS.stringArray(source, kTISPropertyInputSourceLanguages)
        let language = langs.first.map { String($0.prefix(while: { $0 != "-" })) } ?? "und"
        return Layout(id: id, name: name, language: language, source: source) { key in
            Layout.uckTranslate(uchr: uchr, key: key)
        }
    }

    static func uckTranslate(uchr: Data, key: KeyStroke) -> String {
        // modifierKeyState is in the (EventRecord.modifiers >> 8) format: shift = 2, capsLock = 4.
        var modState: UInt32 = 0
        if key.shift { modState |= 2 }
        if key.caps { modState |= 4 }
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 8)
        var length = 0
        let status = uchr.withUnsafeBytes { raw -> OSStatus in
            guard let layoutPtr = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(layoutPtr,
                                  key.keyCode,
                                  UInt16(kUCKeyActionDown),
                                  modState,
                                  UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState,
                                  chars.count,
                                  &length,
                                  &chars)
        }
        guard status == noErr, length > 0 else { return "" }
        return String(utf16CodeUnits: chars, count: length)
    }
}

enum TIS {
    static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let p = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }

    static func stringArray(_ source: TISInputSource, _ key: CFString) -> [String] {
        guard let p = TISGetInputSourceProperty(source, key) else { return [] }
        return (Unmanaged<CFArray>.fromOpaque(p).takeUnretainedValue() as? [String]) ?? []
    }
}
