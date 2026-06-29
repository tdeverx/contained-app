import Foundation

enum RunSpecMemoryFormatter {
    /// Parse a `--memory` spec ("512M", "1G", "2g", bare bytes) into gigabytes.
    static func parseGB(_ spec: String) -> Double? {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return nil }
        if last.isLetter {
            guard let value = Double(trimmed.dropLast()) else { return nil }
            switch last.uppercased() {
            case "G": return value
            case "M": return value / 1024
            case "K": return value / (1024 * 1024)
            case "T": return value * 1024
            default: return nil
            }
        }
        return Double(trimmed).map { $0 / 1_073_741_824 }
    }

    /// Format gigabytes as a `--memory` spec, using `M` for fractional values.
    static func spec(gb: Double) -> String {
        gb.rounded() == gb ? "\(Int(gb))G" : "\(Int(gb * 1024))M"
    }

    static func readout(_ spec: String, fallbackGB: Double) -> String {
        let gb = parseGB(spec) ?? fallbackGB
        if gb < 1 { return "\(Int(gb * 1024)) MB" }
        return gb.rounded() == gb ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
    }
}

extension RunSpec {
    var hasGeneralOptions: Bool {
        !image.trimmingCharacters(in: .whitespaces).isEmpty ||
        !platform.isEmpty ||
        !name.isEmpty ||
        !command.isEmpty ||
        !entrypoint.isEmpty ||
        !detach ||
        removeOnExit
    }

    var hasResourceOptions: Bool {
        !cpus.isEmpty || !memory.isEmpty
    }

    var hasNetworkingOptions: Bool {
        !ports.isEmpty || !network.isEmpty || !sockets.isEmpty
    }

    var hasStorageOptions: Bool {
        !volumes.isEmpty || !mounts.isEmpty
    }

    var hasEnvironmentOptions: Bool {
        !env.isEmpty || !envFiles.isEmpty
    }

    var hasPersonalizationOptions: Bool {
        !personalization.isDefault
    }

    var hasAppManagedOptions: Bool {
        restart != .no || healthCheck.isActive
    }

    var hasAdvancedOptions: Bool {
        interactive || tty ||
        !workingDir.isEmpty ||
        !user.isEmpty ||
        !uid.isEmpty ||
        !gid.isEmpty ||
        !shmSize.isEmpty ||
        !capAdd.isEmpty ||
        !capDrop.isEmpty ||
        !cidFile.isEmpty ||
        !initImage.isEmpty ||
        !kernel.isEmpty ||
        noDNS ||
        !dns.isEmpty ||
        !dnsDomain.isEmpty ||
        !dnsSearch.isEmpty ||
        !dnsOption.isEmpty ||
        !tmpfs.isEmpty ||
        !ulimits.isEmpty ||
        !runtime.isEmpty ||
        !scheme.isEmpty ||
        !progress.isEmpty ||
        !maxConcurrentDownloads.isEmpty ||
        !mounts.isEmpty ||
        !labels.isEmpty ||
        readOnly ||
        useInit ||
        rosetta ||
        ssh ||
        virtualization
    }
}
