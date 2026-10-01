// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypeAny",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(
            name: "CRime",
            path: "Sources/CRime",
            pkgConfig: "rime",
            providers: [.brew(["librime"])]
        ),
        .executableTarget(
            name: "TypeAny",
            dependencies: ["CRime"],
            path: "Sources/TypeAny",
            exclude: ["Resources"]
        )
    ]
)
