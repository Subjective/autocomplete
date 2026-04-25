// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "TabAnywhere",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TabAnywhere", targets: ["TabAnywhere"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/huggingface/AnyLanguageModel",
            from: "0.8.0",
            traits: ["Llama"]
        ),
        .package(url: "https://github.com/huggingface/swift-huggingface", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "TabAnywhere",
            dependencies: [
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel"),
                .product(name: "HuggingFace", package: "swift-huggingface")
            ],
            path: "Sources/TabAnywhere",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
