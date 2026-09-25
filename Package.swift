// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UsageBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "UsageBar", targets: ["UsageBar"]),
        // Claude Code's status line command; the app installs it into ~/.claude/usagebar.
        .executable(name: "usagebar-hook", targets: ["UsageBarHook"]),
    ],
    targets: [
        .executableTarget(name: "UsageBar", path: "Sources/UsageBar"),
        .executableTarget(name: "UsageBarHook", path: "Sources/UsageBarHook"),
    ]
)
