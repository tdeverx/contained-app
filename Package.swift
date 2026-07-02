// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Contained",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Contained", targets: ["Contained"]),
        .library(name: "ContainedCore", targets: ["ContainedCore"]),
        .library(name: "ContainedRuntime", targets: ["ContainedRuntime"]),
        .library(name: "AppleContainerRuntime", targets: ["AppleContainerRuntime"]),
    ],
    dependencies: [
        .package(path: "Packages/ContainedDesignSystem"),
        .package(path: "Packages/ContainedNavigation"),
        // The in-container terminal (Phase 5): a mature VT100/xterm emulator + PTY host, far safer
        // than re-implementing one. AppKit-backed, bridged via NSViewRepresentable.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        // Compose import: a real YAML parser beats a fragile hand-rolled one. Pure Swift.
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        // Auto-update (release): Sparkle, the de-facto macOS updater. Inert until a signed build
        // points SUFeedURL at a hosted appcast (see scripts/appcast.sh).
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        // Pure logic: models, CLI wrapper, decoding, compose parsing. Unit-testable (Yams is pure Swift).
        .target(
            name: "ContainedCore",
            dependencies: [.product(name: "Yams", package: "Yams")],
            path: "Sources/ContainedCore"
        ),
        // Runtime adapter contracts. Keep this generic so Apple container, Docker-compatible,
        // and future engines can share one app-facing capability/client boundary.
        .target(
            name: "ContainedRuntime",
            dependencies: ["ContainedCore"],
            path: "Sources/ContainedRuntime"
        ),
        // Current Apple `container` CLI adapter. Future runtime adapters should be sibling targets,
        // not branches inside the app stores or SwiftUI views.
        .target(
            name: "AppleContainerRuntime",
            dependencies: ["ContainedCore", "ContainedRuntime"],
            path: "Sources/AppleContainerRuntime"
        ),
        // The SwiftUI app, including Sparkle wiring for signed release builds.
        .executableTarget(
            name: "Contained",
            dependencies: [
                "ContainedCore",
                "ContainedRuntime",
                "AppleContainerRuntime",
                .product(name: "ContainedDesignSystem", package: "ContainedDesignSystem"),
                .product(name: "ContainedNavigation", package: "ContainedNavigation"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Contained",
            resources: [.process("Resources")],
            swiftSettings: [
                .define("CONTAINED_DEBUG_TOOLS", .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "ContainedCoreTests",
            dependencies: ["ContainedCore"],
            path: "Tests/ContainedCoreTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ContainedRuntimeTests",
            dependencies: ["ContainedCore", "ContainedRuntime", "AppleContainerRuntime"],
            path: "Tests/ContainedRuntimeTests",
            resources: [.copy("Fixtures")]
        ),
        // Tests for app-target value types (RunSpec form state and runtime-translated create mapping).
        // Imports the
        // executable target with @testable.
        .testTarget(
            name: "ContainedAppTests",
            dependencies: ["Contained", "ContainedCore", "ContainedRuntime", "AppleContainerRuntime"],
            path: "Tests/ContainedAppTests"
        ),
        .testTarget(
            name: "ContainedDesignSystemTests",
            dependencies: [.product(name: "ContainedDesignSystem", package: "ContainedDesignSystem")],
            path: "Tests/ContainedDesignSystemTests"
        ),
        .testTarget(
            name: "ContainedNavigationTests",
            dependencies: [.product(name: "ContainedNavigation", package: "ContainedNavigation")],
            path: "Tests/ContainedNavigationTests"
        ),
    ]
)
