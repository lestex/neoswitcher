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
    lazy var corrector = Corrector(layouts: layouts)
    let scorer = DictionaryScorer()
    lazy var detector = Detector(scorer: scorer)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reset on app switch.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.buffer.reset()
            self?.corrector.clearUndo()
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
        if IsSecureEventInputEnabled() { buffer.reset(); corrector.clearUndo(); return }

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
        guard case .wordEnded(let keys) = buffer.handleKeyDown(keyCode: code, modifiers: mods, isAutorepeat: auto) else { return }

        guard let current = layouts.current() else {
            Log.decision("skipped: current layout has no uchr, len=\(keys.count)")
            return
        }
        let alts = layouts.alternatives(to: current)
        if let c = detector.detect(keys: keys, current: current, alternatives: alts) {
            Log.content("\(c.original) -> \(c.corrected)")
            // Perform outside the tap callback.
            DispatchQueue.main.async { [corrector] in corrector.correct(c, from: current) }
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
