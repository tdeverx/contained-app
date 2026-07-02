// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedRuntime",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedRuntime", targets: ["ContainedRuntime"]),
    ],
    dependencies: [
        .package(path: "../ContainedCore"),
    ],
    targets: [
        .target(
            name: "ContainedRuntime",
            dependencies: [
                .product(name: "ContainedCore", package: "ContainedCore"),
            ]
        ),
        .testTarget(
            name: "ContainedRuntimeTests",
            dependencies: [
                "ContainedRuntime",
                .product(name: "ContainedCore", package: "ContainedCore"),
            ]
        ),
    ]
)
