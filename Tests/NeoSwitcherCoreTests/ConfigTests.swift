import Foundation
import Testing
@testable import NeoSwitcherCore

@Suite struct ConfigTests {
    @Test func defaultsExcludeTerminalsAndPasswordManagers() {
        let c = Config()
        for id in ["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty",
                   "com.1password.1password", "com.bitwarden.desktop"] {
            #expect(c.excludedBundleIDs.contains(id))
        }
    }

    @Test func parseOverrides() throws {
        let json = #"{"excludedBundleIDs":["a.b"],"eventDelayMicros":3000,"pauseHotkey":{"keyCode":40,"modifiers":["ctrl","shift"]}}"#
        let c = try #require(Config.parse(Data(json.utf8)))
        #expect(c.excludedBundleIDs == ["a.b"])
        #expect(c.eventDelayMicros == 3000)
        #expect(c.pauseHotkey == Hotkey(keyCode: 40, modifiers: [.control, .shift]))
    }

    @Test func badModifierOrJSONFallsBack() {
        #expect(Config.parse(Data(#"{"pauseHotkey":{"keyCode":1,"modifiers":["bogus"]}}"#.utf8)) == nil)
        #expect(Config.load(from: URL(fileURLWithPath: "/nonexistent/config.json")) == Config())
    }

    @Test func hotkeyMatching() {
        let h = Hotkey.defaultPause
        #expect(h.matches(keyCode: 35, modifiers: [.control, .option, .command]))
        #expect(h.matches(keyCode: 35, modifiers: [.control, .option, .command, .caps]))
        #expect(!h.matches(keyCode: 35, modifiers: [.control, .option]))
        #expect(!h.matches(keyCode: 35, modifiers: [.control, .option, .command, .shift]))
        #expect(!h.matches(keyCode: 34, modifiers: [.control, .option, .command]))
    }
}
