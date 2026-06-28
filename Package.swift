// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Toggle",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Toggle",
            path: "Sources/Toggle",
            linkerSettings: [
                // CoreBrightness is a private framework backing Night Shift / True Tone.
                .unsafeFlags([
                    "-F", "/System/Library/PrivateFrameworks",
                    "-framework", "CoreBrightness",
                    "-framework", "IOBluetooth",
                ])
            ]
        )
    ]
)
