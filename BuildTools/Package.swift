// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [
        .macOS(.v10_11),
    ],
    dependencies: [
        .package(
            url: "https://github.com/nicklockwood/SwiftFormat.git",
            from: "0.56.1"
        ),
    ],
    targets: [
        .target(
            name: "BuildTools",
            path: ""
        ),
    ]
)
