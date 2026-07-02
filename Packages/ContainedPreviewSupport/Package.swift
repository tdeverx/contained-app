// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedPreviewSupport",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedPreviewSupport", targets: ["ContainedPreviewSupport"]),
    ],
    dependencies: [
        .package(path: "../ContainedCore"),
        .package(path: "../ContainedRuntime"),
    ],
    targets: [
        .target(
            name: "ContainedPreviewSupport",
            dependencies: [
                .product(name: "ContainedCore", package: "ContainedCore"),
                .product(name: "ContainedRuntime", package: "ContainedRuntime"),
            ]
        ),
        .testTarget(
            name: "ContainedPreviewSupportTests",
            dependencies: ["ContainedPreviewSupport"]
        ),
    ]
)
