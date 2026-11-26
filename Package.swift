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
