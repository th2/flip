// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "flip",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "flip",
            path: "Sources/flip"
        )
    ]
)
