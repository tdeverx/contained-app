// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedCore", targets: ["ContainedCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
    ],
    targets: [
        .target(
            name: "ContainedCore",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .testTarget(
            name: "ContainedCoreTests",
            dependencies: ["ContainedCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
