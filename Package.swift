// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "partout-codegen",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "PartoutCodegen",
            targets: ["PartoutCodegen"]
        ),
        .executable(
            name: "partout-codegen",
            targets: ["codegen"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "PartoutCodegen",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "codegen",
            dependencies: [
                "PartoutCodegen",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "PartoutCodegenTests",
            dependencies: ["PartoutCodegen"]
        )
    ]
)
