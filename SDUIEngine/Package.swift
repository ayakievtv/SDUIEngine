// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SDUIEngine",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SDUIEngine",
            targets: ["SDUIEngine"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SDUIEngine",
            path: "SDUIEngine"
        ),
        .testTarget(
            name: "SDUIEngineTests",
            dependencies: ["SDUIEngine"],
            path: "SDUIEngineTests"
        ),
        .testTarget(
            name: "SDUIEngineNewTests",
            dependencies: ["SDUIEngine"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
