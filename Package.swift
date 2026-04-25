// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TabAnywhere",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TabAnywhere", targets: ["TabAnywhere"])
    ],
    targets: [
        .executableTarget(
            name: "TabAnywhere",
            path: "Sources/TabAnywhere"
        )
    ]
)
