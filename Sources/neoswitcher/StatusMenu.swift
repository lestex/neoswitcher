import AppKit
import ServiceManagement

/// Menu bar item: state, pause toggle, last correction (layout names only), login item, quit.
final class StatusMenu: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stateItem = NSMenuItem()
    private let toggleItem = NSMenuItem()
    private let lastItem = NSMenuItem()
    private let loginItem = NSMenuItem()
    private let inputMonitoringItem = NSMenuItem()
    private let accessibilityItem = NSMenuItem()

    var isPaused = false { didSet { refresh() } }
    var lastCorrection: String? { didSet { refresh() } }
    var onTogglePause: (() -> Void)?

    /// Set from the permission poll; drives the warning icon and the "Grant…" items.
    var missingInputMonitoring = false { didSet { if oldValue != missingInputMonitoring { refresh() } } }
    var missingAccessibility = false { didSet { if oldValue != missingAccessibility { refresh() } } }
    private var needsPermissions: Bool { missingInputMonitoring || missingAccessibility }

    override init() {
        super.init()
        let menu = NSMenu()
        stateItem.isEnabled = false
        lastItem.isEnabled = false
        toggleItem.target = self
        toggleItem.action = #selector(togglePause)
        inputMonitoringItem.title = "Grant Input Monitoring…"
        inputMonitoringItem.target = self
        inputMonitoringItem.action = #selector(openInputMonitoring)
        accessibilityItem.title = "Grant Accessibility…"
        accessibilityItem.target = self
        accessibilityItem.action = #selector(openAccessibility)
        loginItem.title = "Launch at Login"
        loginItem.target = self
        loginItem.action = #selector(toggleLogin)
        let quit = NSMenuItem(title: "Quit NeoSwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        [stateItem, inputMonitoringItem, accessibilityItem, toggleItem, lastItem, .separator(), loginItem, .separator(), quit].forEach(menu.addItem)
        item.menu = menu
        refresh()
    }

    private func refresh() {
        let symbol = needsPermissions ? "exclamationmark.triangle" : (isPaused ? "keyboard.badge.ellipsis" : "keyboard")
        if let button = item.button {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "NeoSwitcher")
            if button.image == nil { button.title = needsPermissions ? "⚠︎" : (isPaused ? "⏸" : "⌨︎") }
        }
        stateItem.title = needsPermissions ? "Permissions needed" : (isPaused ? "Paused" : "Enabled")
        inputMonitoringItem.isHidden = !missingInputMonitoring
        accessibilityItem.isHidden = !missingAccessibility
        toggleItem.title = isPaused ? "Resume" : "Pause"
        lastItem.title = "Last correction: " + (lastCorrection ?? "none")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func openInputMonitoring() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    @objc private func openAccessibility() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func open(_ url: String) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
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
