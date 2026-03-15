// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PuzzleTool",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "PuzzleTool",
            path: "Sources/PuzzleTool",
            resources: [
                .copy("Resources/enable.txt")
            ]
        )
    ]
)
