// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Contained",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Contained", targets: ["Contained"]),
        .library(name: "ContainedApp", targets: ["ContainedApp"]),
    ],
    dependencies: [
        .package(path: "Packages/ContainedCore"),
        .package(path: "Packages/ContainedUI"),
        .package(path: "Packages/ContainedUX"),
        // Mature VT100/xterm emulator + PTY host for the in-container terminal. AppKit-backed,
        // bridged through NSViewRepresentable in the app target.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        // Auto-update (release): Sparkle, the de-facto macOS updater. Inert until a signed build
        // points SUFeedURL at a hosted appcast (see Scripts/appcast.sh).
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        // Shared SwiftUI app implementation. SwiftPM and Xcode use different tiny launchers.
        .target(
            name: "ContainedApp",
            dependencies: [
                .product(name: "ContainedCore", package: "ContainedCore"),
                .product(name: "ContainedUI", package: "ContainedUI"),
                .product(name: "ContainedUX", package: "ContainedUX"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/ContainedApp",
            resources: [.process("Resources")],
            swiftSettings: [
                .define("CONTAINED_DEBUG_TOOLS", .when(configuration: .debug)),
            ]
        ),
        // SwiftPM executable launcher used by bundle/release scripts.
        .executableTarget(
            name: "Contained",
            dependencies: ["ContainedApp"],
            path: "Sources/Contained"
        ),
        // Tests for app-owned value types, runtime mapping, and fixture-to-presentation mapping.
        // Imports the shared app module with @testable and keeps fixtures out of the app target.
        .testTarget(
            name: "ContainedAppTests",
            dependencies: [
                "ContainedApp",
                .product(name: "ContainedCore", package: "ContainedCore"),
                .product(name: "ContainedCoreFixtures", package: "ContainedCore"),
            ],
            path: "Tests/ContainedAppTests"
        ),
    ]
)
