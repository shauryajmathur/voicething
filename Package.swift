// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VoiceThing",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceThing", targets: ["VoiceThing"])
    ],
    targets: [
        .target(
            name: "VoiceThingCore",
            path: "Sources/VoiceThingCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "VoiceThing",
            dependencies: ["VoiceThingCore"],
            path: "Sources/VoiceThing"
        ),
        .testTarget(
            name: "VoiceThingCoreTests",
            dependencies: ["VoiceThingCore"],
            path: "Tests/VoiceThingCoreTests"
        )
    ]
)
