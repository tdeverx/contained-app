import OSLog

/// Static, privacy-safe Instruments intervals for the app's high-traffic data paths.
/// Signpost payloads intentionally contain no resource identifiers or user content.
enum PerformanceSignposts {
    static let activity = OSSignposter(subsystem: "app.contained.Contained",
                                       category: "performance.activity")
    static let grid = OSSignposter(subsystem: "app.contained.Contained",
                                   category: "performance.grid")
    static let inventory = OSSignposter(subsystem: "app.contained.Contained",
                                        category: "performance.inventory")
}
