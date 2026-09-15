// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacroPad",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacroPad",
            path: "Sources/MacroPad",
            swiftSettings: [.unsafeFlags(["-Onone"])],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Carbon"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
