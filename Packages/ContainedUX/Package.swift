// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedUX",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedUX", targets: ["ContainedUX"]),
    ],
    dependencies: [
        .package(path: "../ContainedUI"),
    ],
    targets: [
        .target(
            name: "ContainedUX",
            dependencies: [
                .product(name: "ContainedUI", package: "ContainedUI"),
            ]
        ),
        .testTarget(
            name: "ContainedUXTests",
            dependencies: ["ContainedUX"]
        ),
    ]
)
