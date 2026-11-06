import Foundation
@testable import NeoSwitcherCore

/// Carbon TIS calls must run on the main thread, but Swift Testing runs tests in parallel on
/// background threads. Enumerate the real layouts once, on the main thread, and share them.
func onMain<T>(_ body: () -> T) -> T {
    Thread.isMainThread ? body() : DispatchQueue.main.sync(execute: body)
}

let sharedLayoutManager: LayoutManager = onMain { LayoutManager() }
