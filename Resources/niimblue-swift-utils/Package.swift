// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "niimblue-swift",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NiimblueLib",
            targets: ["NiimblueLib"]),
        .executable(
            name: "niimblue-cli",
            targets: ["niimblue-cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/armadsen/ORSSerialPort.git", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "NiimblueLib",
            dependencies: [
                .product(name: "ORSSerial", package: "ORSSerialPort"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
        .executableTarget(
            name: "niimblue-cli",
            dependencies: [
                "NiimblueLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
    ]
)
