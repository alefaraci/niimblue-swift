// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "niimblue-swift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "niimblue-cli", targets: ["niimblue-cli"]),
        .library(name: "NiimblueLib", targets: ["NiimblueLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/yeokm1/SwiftSerial.git", from: "0.1.2"), 
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NiimblueLib",
            dependencies: [
                "SwiftSerial"
            ]
        ),
        .executableTarget(
            name: "niimblue-cli",
            dependencies: [
                "NiimblueLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
