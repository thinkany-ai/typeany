// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypeAny",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TypeAny",
            path: "Sources/TypeAny",
            exclude: ["Resources/Info.plist"]
        )
    ]
)
