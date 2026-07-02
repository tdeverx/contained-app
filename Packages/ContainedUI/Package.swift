// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContainedUI",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ContainedUI", targets: ["ContainedUI"]),
    ],
    targets: [
        .target(name: "ContainedUI"),
        .testTarget(
            name: "ContainedUITests",
            dependencies: ["ContainedUI"]
        ),
    ]
)
