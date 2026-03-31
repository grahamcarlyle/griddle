// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Griddle",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "GriddleLib",
            path: "Sources/GriddleLib"
        ),
        .executableTarget(
            name: "Griddle",
            dependencies: ["GriddleLib"],
            path: "Sources/Griddle"
        ),
        .testTarget(
            name: "GriddleTests",
            dependencies: ["GriddleLib"],
            path: "Tests/GriddleTests"
        )
    ]
)
