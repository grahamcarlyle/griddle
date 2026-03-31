// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Griddle",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Griddle",
            path: "Sources/Griddle"
        )
    ]
)
