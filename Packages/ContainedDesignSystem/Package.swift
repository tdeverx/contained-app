// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedDesignSystem",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedDesignSystem", targets: ["ContainedDesignSystem"]),
    ],
    targets: [
        .target(name: "ContainedDesignSystem"),
        .testTarget(
            name: "ContainedDesignSystemTests",
            dependencies: ["ContainedDesignSystem"]
        ),
    ]
)
