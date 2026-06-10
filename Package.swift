// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "headroom",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "headroom",
            dependencies: [],
            path: "Sources/headroom"
        ),
        .testTarget(
            name: "headroomTests",
            dependencies: ["headroom"],
            path: "Tests/headroomTests"
        )
    ]
)
