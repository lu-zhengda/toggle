// swift-tools-version:6.2
import PackageDescription
let package = Package(
    name: "Mock",
    platforms: [.macOS("26.0")],
    targets: [.executableTarget(name: "Mock", path: "Sources/Mock",
        swiftSettings: [.swiftLanguageMode(.v5)])]
)
