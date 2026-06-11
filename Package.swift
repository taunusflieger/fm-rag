// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FMRag",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "fm-rag", targets: ["FMRagCLI"]),
        .library(name: "FMRagCore", targets: ["FMRagCore"])
    ],
    targets: [
        .executableTarget(
            name: "FMRagCLI",
            dependencies: ["FMRagCore"]
        ),
        .target(name: "FMRagCore"),
        .testTarget(
            name: "FMRagCoreTests",
            dependencies: ["FMRagCore"]
        )
    ]
)
