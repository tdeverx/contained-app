// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedCore", targets: ["ContainedCore"]),
        .library(name: "ContainedCoreFixtures", targets: ["ContainedCoreFixtures"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
    ],
    targets: [
        .target(
            name: "ContainedCore",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .target(
            name: "ContainedCoreFixtures",
            dependencies: ["ContainedCore"],
            swiftSettings: [
                .define("CONTAINED_CORE_FIXTURES"),
            ]
        ),
        .testTarget(
            name: "ContainedCoreTests",
            dependencies: ["ContainedCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ContainedCoreFixturesTests",
            dependencies: ["ContainedCoreFixtures"]
        ),
    ]
)
