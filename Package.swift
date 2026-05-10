// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Livable",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Livable",
            targets: ["Livable"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Livable",
            resources: [
                .process("Shaders")
            ]
        ),
        .testTarget(
            name: "LivableTests",
            dependencies: ["Livable"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
