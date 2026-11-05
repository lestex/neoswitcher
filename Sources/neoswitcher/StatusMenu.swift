import AppKit
import ServiceManagement

/// Menu bar item: state, pause toggle, last correction (layout names only), login item, quit.
final class StatusMenu: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stateItem = NSMenuItem()
    private let toggleItem = NSMenuItem()
    private let lastItem = NSMenuItem()
    private let loginItem = NSMenuItem()

    var isPaused = false { didSet { refresh() } }
    var lastCorrection: String? { didSet { refresh() } }
    var onTogglePause: (() -> Void)?

    override init() {
        super.init()
        let menu = NSMenu()
        stateItem.isEnabled = false
        lastItem.isEnabled = false
        toggleItem.target = self
        toggleItem.action = #selector(togglePause)
        loginItem.title = "Launch at Login"
        loginItem.target = self
        loginItem.action = #selector(toggleLogin)
        let quit = NSMenuItem(title: "Quit NeoSwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        [stateItem, toggleItem, lastItem, .separator(), loginItem, .separator(), quit].forEach(menu.addItem)
        item.menu = menu
        refresh()
    }

    private func refresh() {
        let symbol = isPaused ? "keyboard.badge.ellipsis" : "keyboard"
        if let button = item.button {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "NeoSwitcher")
            if button.image == nil { button.title = isPaused ? "⏸" : "⌨︎" }
        }
        stateItem.title = isPaused ? "Paused" : "Enabled"
        toggleItem.title = isPaused ? "Resume" : "Pause"
        lastItem.title = "Last correction: " + (lastCorrection ?? "none")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func togglePause() { onTogglePause?() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let a = NSAlert()
            a.messageText = "Could not change login item"
            a.informativeText = "\(error.localizedDescription)\nThis only works when running the signed .app bundle."
            a.runModal()
        }
        refresh()
    }
}
