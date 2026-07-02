// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppleContainerRuntime",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AppleContainerRuntime", targets: ["AppleContainerRuntime"]),
    ],
    dependencies: [
        .package(path: "../ContainedCore"),
        .package(path: "../ContainedRuntime"),
    ],
    targets: [
        .target(
            name: "AppleContainerRuntime",
            dependencies: [
                .product(name: "ContainedCore", package: "ContainedCore"),
                .product(name: "ContainedRuntime", package: "ContainedRuntime"),
            ]
        ),
        .testTarget(
            name: "AppleContainerRuntimeTests",
            dependencies: [
                "AppleContainerRuntime",
                .product(name: "ContainedCore", package: "ContainedCore"),
                .product(name: "ContainedRuntime", package: "ContainedRuntime"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
