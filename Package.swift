// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FMRag",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "fm-rag", targets: ["FMRagCLI"]),
        .library(name: "FMRagCore", targets: ["FMRagCore"])
    ],
    dependencies: [
        .package(path: "../coreai-models")
    ],
    targets: [
        .executableTarget(
            name: "FMRagCLI",
            dependencies: [
                "FMRagCore",
                .product(name: "CoreAILM", package: "coreai-models"),
            ]
        ),
        .target(name: "FMRagCore"),
        .testTarget(
            name: "FMRagCoreTests",
            dependencies: ["FMRagCore"]
        )
    ]
)
