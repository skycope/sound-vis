// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SoundVisCLI",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SoundVisCLI",
            path: "Sources/SoundVisCLI"
        )
    ]
)
