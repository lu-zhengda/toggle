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
                // CoreBrightness is resolved dynamically by the feature bridges so
                // API drift can degrade gracefully instead of failing at launch.
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreWLAN"),
            ]
        ),
        .testTarget(
            name: "ToggleTests",
            dependencies: ["Toggle"]
        ),
    ]
)
