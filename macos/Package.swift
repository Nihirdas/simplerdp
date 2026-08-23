// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleRDP",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SimpleRDP",
            path: "Sources/SimpleRDP"
        )
    ]
)
