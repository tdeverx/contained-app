// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedNavigation",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedNavigation", targets: ["ContainedNavigation"]),
    ],
    dependencies: [
        .package(path: "../ContainedDesignSystem"),
    ],
    targets: [
        .target(
            name: "ContainedNavigation",
            dependencies: [
                .product(name: "ContainedDesignSystem", package: "ContainedDesignSystem"),
            ]
        ),
    ]
)
