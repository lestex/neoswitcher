import Testing
@testable import NeoSwitcherCore

@Suite struct WordBufferTests {
    private func type(_ b: inout WordBuffer, _ codes: [UInt16], mods: Modifiers = []) {
        for c in codes { b.handleKeyDown(keyCode: c, modifiers: mods, isAutorepeat: false) }
    }

    // g h b d t n
    private let ghbdtn: [UInt16] = [5, 4, 11, 2, 17, 45]

    @Test func spaceEndsWordAndClears() {
        var b = WordBuffer()
        type(&b, ghbdtn)
        let ev = b.handleKeyDown(keyCode: KeyCode.space, modifiers: [], isAutorepeat: false)
        #expect(ev == .wordEnded(ghbdtn.map { KeyStroke(keyCode: $0) }, terminator: KeyCode.space))
        #expect(b.isEmpty)
    }

    @Test func emptySpaceDoesNothing() {
        var b = WordBuffer()
        #expect(b.handleKeyDown(keyCode: KeyCode.space, modifiers: [], isAutorepeat: false) == .none)
    }

    @Test func backspacePopsAndIgnoresEmpty() {
        var b = WordBuffer()
        b.handleKeyDown(keyCode: KeyCode.delete, modifiers: [], isAutorepeat: false)
        type(&b, [5, 4])
        b.handleKeyDown(keyCode: KeyCode.delete, modifiers: [], isAutorepeat: false)
        #expect(b.keys == [KeyStroke(keyCode: 5)])
    }

    @Test func backspaceAutorepeatPops_otherAutorepeatIgnored() {
        var b = WordBuffer()
        type(&b, [5, 4, 11])
        b.handleKeyDown(keyCode: KeyCode.delete, modifiers: [], isAutorepeat: true)
        #expect(b.keys.count == 2)
        b.handleKeyDown(keyCode: 0, modifiers: [], isAutorepeat: true)
        #expect(b.keys.count == 2)
    }

    @Test func shiftAndCapsRecorded() {
        var b = WordBuffer()
        b.handleKeyDown(keyCode: 5, modifiers: [.shift, .caps], isAutorepeat: false)
        #expect(b.keys == [KeyStroke(keyCode: 5, shift: true, caps: true)])
    }

    @Test func punctuationKeysBuffered() {
        var b = WordBuffer()
        type(&b, [43, 47, 41, 39, 33, 30, 50]) // , . ; ' [ ] `
        #expect(b.keys.count == 7)
    }

    // return, tab, escape, arrows, home, end, pgup, pgdn, F-keys
    @Test(arguments: [36, 48, 53, 123, 124, 125, 126, 115, 119, 116, 121, 122, 111, 122] as [UInt16])
    func resetKeys(code: UInt16) {
        var b = WordBuffer()
        type(&b, [5, 4])
        b.handleKeyDown(keyCode: code, modifiers: [], isAutorepeat: false)
        #expect(b.isEmpty)
    }

    @Test(arguments: [Modifiers.command, .control, .option])
    func chordsReset(m: Modifiers) {
        var b = WordBuffer()
        type(&b, [5, 4])
        b.handleKeyDown(keyCode: 8, modifiers: m, isAutorepeat: false)
        #expect(b.isEmpty)
    }

    @Test func overflowAndManualReset() {
        var b = WordBuffer()
        type(&b, Array(repeating: 0, count: WordBuffer.maxLength + 5))
        #expect(b.keys.count == WordBuffer.maxLength)
        #expect(b.handleKeyDown(keyCode: KeyCode.space, modifiers: [], isAutorepeat: false) == .none)
        #expect(b.isEmpty)
        type(&b, [5])
        b.reset()
        #expect(b.isEmpty)
    }

    @Test func returnAndTabEndWordsOnlyWhenConfigured() {
        var b = WordBuffer(wordEndKeys: [KeyCode.space, KeyCode.returnKey, KeyCode.tab])
        type(&b, ghbdtn)
        #expect(b.handleKeyDown(keyCode: KeyCode.returnKey, modifiers: [], isAutorepeat: false)
                == .wordEnded(ghbdtn.map { KeyStroke(keyCode: $0) }, terminator: KeyCode.returnKey))
        type(&b, ghbdtn)
        #expect(b.handleKeyDown(keyCode: KeyCode.tab, modifiers: [], isAutorepeat: false)
                == .wordEnded(ghbdtn.map { KeyStroke(keyCode: $0) }, terminator: KeyCode.tab))
        // Empty buffer + Return is a no-op, and other reset keys still reset.
        #expect(b.handleKeyDown(keyCode: KeyCode.returnKey, modifiers: [], isAutorepeat: false) == .none)
        type(&b, [5, 4])
        b.handleKeyDown(keyCode: 123, modifiers: [], isAutorepeat: false)
        #expect(b.isEmpty)
    }

    @Test func defaultBufferIgnoresReturnAsTerminator() {
        var b = WordBuffer()
        type(&b, ghbdtn)
        #expect(b.handleKeyDown(keyCode: KeyCode.returnKey, modifiers: [], isAutorepeat: false) == .none)
        #expect(b.isEmpty)
    }

    @Test func emptyWordEndSetFallsBackToSpace() {
        var b = WordBuffer(wordEndKeys: [])
        type(&b, ghbdtn)
        if case .wordEnded(_, let t) = b.handleKeyDown(keyCode: KeyCode.space, modifiers: [], isAutorepeat: false) {
            #expect(t == KeyCode.space)
        } else {
            Issue.record("space should end the word")
        }
    }
}
