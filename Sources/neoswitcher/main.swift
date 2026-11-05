import AppKit
import Carbon
import NeoSwitcherCore

let args = CommandLine.arguments
Log.debugContent = args.contains("--debug-content")
Log.verbose = args.contains("--verbose") || Log.debugContent

final class AppDelegate: NSObject, NSApplicationDelegate {
    let layouts = LayoutManager()
    var buffer = WordBuffer()
    let tap = EventTap()
    var retryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reset on app switch.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.buffer.reset() }

        tap.onMouseDown = { [weak self] in self?.buffer.reset() }
        tap.onKeyDown = { [weak self] code, mods, auto in self?.handleKey(code, mods, auto) }

        Log.info("enabled layouts: " + layouts.layouts.map { "\($0.id)[\($0.language)]" }.joined(separator: ", "))
        startTapWhenPermitted()
    }

    func startTapWhenPermitted() {
        let ax = Permissions.accessibilityGranted(prompt: true)
        var im = Permissions.inputMonitoringGranted()
        if !im { im = Permissions.requestInputMonitoring() }
        if tap.install() {
            Log.info("event tap installed" + (ax ? "" : " (Accessibility still missing: corrections will not be typed)"))
            return
        }
        Permissions.printInstructions(accessibility: ax, inputMonitoring: im)
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] t in
            guard let self else { return }
            if self.tap.install() {
                t.invalidate()
                Log.info("event tap installed")
            }
        }
    }

    func handleKey(_ code: UInt16, _ mods: Modifiers, _ auto: Bool) {
        if IsSecureEventInputEnabled() { buffer.reset(); return }
        guard case .wordEnded(let keys) = buffer.handleKeyDown(keyCode: code, modifiers: mods, isAutorepeat: auto) else { return }

        // Phase 1: just report decisions-level info. Detection arrives in phase 2.
        guard let current = layouts.current() else {
            Log.decision("word ended len=\(keys.count) current layout has no uchr; skipped")
            return
        }
        Log.decision("word ended len=\(keys.count) layout=\(current.id)")
        if Log.debugContent {
            let alts = layouts.alternatives(to: current)
            let rendering = ([current] + alts).map { "\($0.language)=\($0.translate(keys))" }.joined(separator: " ")
            Log.content(rendering)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
