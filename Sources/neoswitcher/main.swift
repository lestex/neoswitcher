import AppKit
import Carbon
import NeoSwitcherCore

let args = CommandLine.arguments
Log.debugContent = args.contains("--debug-content")
Log.verbose = args.contains("--verbose") || Log.debugContent

final class AppDelegate: NSObject, NSApplicationDelegate {
    let config = Config.load()
    let layouts = LayoutManager()
    lazy var buffer = WordBuffer(wordEndKeys: config.wordEndKeyCodes)
    let tap = EventTap()
    let menu = StatusMenu()
    lazy var corrector = Corrector(layouts: layouts)
    let scorer = DictionaryScorer()
    lazy var detector = Detector(scorer: scorer)
    var permissionTimer: Timer?
    var lastAX: Bool?
    var lastIM: Bool?
    var paused = false
    var frontmostExcluded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        corrector.eventDelayMicros = config.eventDelayMicros
        corrector.onChange = { [weak self] in self?.menu.lastCorrection = self?.corrector.lastDescription }
        menu.onTogglePause = { [weak self] in self?.togglePause() }
        updateFrontmost(NSWorkspace.shared.frontmostApplication)

        // App switch: reset state and re-evaluate exclusion (cached, never queried per key).
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.buffer.reset()
            self?.corrector.clearUndo()
            self?.updateFrontmost(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }

        tap.onMouseDown = { [weak self] in
            self?.buffer.reset()
            self?.corrector.clearUndo()
        }
        tap.onKeyDown = { [weak self] code, mods, auto in self?.handleKey(code, mods, auto) }

        Log.info("enabled layouts: " + layouts.layouts.map { "\($0.id)[\($0.language)]" }.joined(separator: ", "))
        preloadWordLists()
        startTapWhenPermitted()
    }

    func updateFrontmost(_ app: NSRunningApplication?) {
        let id = app?.bundleIdentifier
        frontmostExcluded = id.map(config.excludedBundleIDs.contains) ?? false
        Log.decision("frontmost excluded=\(frontmostExcluded)")
    }

    func togglePause() {
        paused.toggle()
        menu.isPaused = paused
        buffer.reset()
        corrector.clearUndo()
        Log.info(paused ? "paused" : "resumed")
    }

    /// Load dictionaries off the main thread; never inside the tap callback.
    func preloadWordLists() {
        let languages = Array(Set(layouts.layouts.map(\.language)))
        DispatchQueue.global(qos: .utility).async { [scorer] in
            let list = WordList.load(languages: languages)
            DispatchQueue.main.async {
                scorer.list = list
                Log.info("word lists loaded: " + languages.sorted().map { "\($0)=\(list.words[$0]?.count ?? 0)" }.joined(separator: " "))
            }
        }
    }

    /// Asks for both permissions once, then polls: the menu shows what is missing and the tap
    /// is installed as soon as Input Monitoring is granted (no relaunch needed).
    func startTapWhenPermitted() {
        _ = Permissions.accessibilityGranted(prompt: true)
        if !Permissions.inputMonitoringGranted() { Permissions.requestInputMonitoring() }
        refreshPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
    }

    func refreshPermissions() {
        let ax = Permissions.accessibilityGranted(prompt: false)
        let im = Permissions.inputMonitoringGranted()
        if ax != lastAX || im != lastIM {
            lastAX = ax
            lastIM = im
            Log.info("permissions: accessibility=\(ax) inputMonitoring=\(im)")
            if !ax || !im { Permissions.printInstructions(accessibility: ax, inputMonitoring: im) }
        }
        menu.missingAccessibility = !ax
        menu.missingInputMonitoring = !im
        if !tap.isInstalled, im, tap.install() { Log.info("event tap installed") }
    }

    func handleKey(_ code: UInt16, _ mods: Modifiers, _ auto: Bool) {
        // Pause hotkey works everywhere (before chord reset and exclusions). The tap is
        // listen-only, so the key combo still reaches the frontmost app.
        if !auto, config.pauseHotkey.matches(keyCode: code, modifiers: mods) {
            DispatchQueue.main.async { [weak self] in self?.togglePause() }
            return
        }
        if paused || frontmostExcluded || IsSecureEventInputEnabled() {
            buffer.reset()
            corrector.clearUndo()
            return
        }

        // Backspace right after a correction undoes it; any other key forgets the correction.
        if corrector.hasPendingUndo {
            if code == KeyCode.delete, mods.isDisjoint(with: .chord), !auto {
                buffer.reset()
                // Outside the tap callback; undo() clears its own state first.
                DispatchQueue.main.async { [corrector] in corrector.undo() }
                return
            }
            corrector.clearUndo()
        }

        guard case .wordEnded(let keys, let terminator) = buffer.handleKeyDown(keyCode: code, modifiers: mods, isAutorepeat: auto) else { return }

        guard let current = layouts.current() else {
            Log.decision("skipped: current layout has no uchr, len=\(keys.count)")
            return
        }
        let alts = layouts.alternatives(to: current)
        if let c = detector.detect(keys: keys, current: current, alternatives: alts) {
            Log.content("\(c.original) -> \(c.corrected)")
            // Perform outside the tap callback; re-check pause at post time.
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.paused else { return }
                self.corrector.correct(c, from: current, terminator: terminator)
            }
        } else {
            Log.decision("skipped: no correction, layout=\(current.id), len=\(keys.count)")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
