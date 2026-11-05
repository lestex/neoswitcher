// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NeoSwitcher",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NeoSwitcherCore"),
        .executableTarget(name: "neoswitcher", dependencies: ["NeoSwitcherCore"]),
        .testTarget(name: "NeoSwitcherCoreTests", dependencies: ["NeoSwitcherCore"]),
    ]
)
