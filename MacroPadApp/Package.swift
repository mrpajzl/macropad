// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacroPad",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/NordicSemiconductor/IOS-DFU-Library.git", exact: "4.17.0")],
    targets: [
        .executableTarget(
            name: "MacroPad",
            dependencies: [.product(name: "NordicDFU", package: "IOS-DFU-Library")],
            path: "Sources/MacroPad",
            swiftSettings: [.unsafeFlags(["-Onone"])],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(name: "MacroPadTests", dependencies: ["MacroPad"])
    ],
    swiftLanguageVersions: [.v5]
)
