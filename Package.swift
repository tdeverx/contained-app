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
        .package(path: "Packages/ContainedRuntime"),
        .package(path: "Packages/AppleContainerRuntime"),
        .package(path: "Packages/ContainedDesignSystem"),
        .package(path: "Packages/ContainedNavigation"),
        .package(path: "Packages/ContainedPreviewSupport"),
        // The in-container terminal (Phase 5): a mature VT100/xterm emulator + PTY host, far safer
        // than re-implementing one. AppKit-backed, bridged via NSViewRepresentable.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        // Auto-update (release): Sparkle, the de-facto macOS updater. Inert until a signed build
        // points SUFeedURL at a hosted appcast (see scripts/appcast.sh).
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        // Shared SwiftUI app implementation. SwiftPM and Xcode use different tiny launchers.
        .target(
            name: "ContainedApp",
            dependencies: [
                .product(name: "ContainedCore", package: "ContainedCore"),
                .product(name: "ContainedRuntime", package: "ContainedRuntime"),
                .product(name: "AppleContainerRuntime", package: "AppleContainerRuntime"),
                .product(name: "ContainedDesignSystem", package: "ContainedDesignSystem"),
                .product(name: "ContainedNavigation", package: "ContainedNavigation"),
                .product(name: "ContainedPreviewSupport", package: "ContainedPreviewSupport"),
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
        // Tests for app-target value types (RunSpec form state and runtime-translated create mapping).
        // Imports the shared app module with @testable.
        .testTarget(
            name: "ContainedAppTests",
            dependencies: [
                "ContainedApp",
                .product(name: "ContainedCore", package: "ContainedCore"),
                .product(name: "ContainedRuntime", package: "ContainedRuntime"),
                .product(name: "AppleContainerRuntime", package: "AppleContainerRuntime"),
            ],
            path: "Tests/ContainedAppTests"
        ),
    ]
)
