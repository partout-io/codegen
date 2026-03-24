// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "codegen",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "CodegenLibrary",
            targets: ["CodegenLibrary"]
        ),
        .executable(
            name: "codegen",
            targets: ["codegen"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "CodegenLibrary",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "codegen",
            dependencies: [
                "CodegenLibrary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "CodegenLibraryTests",
            dependencies: ["CodegenLibrary"]
        )
    ]
)
