import Foundation
import ContainedCore

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
    var normalizedImageReference: String {
        Self.normalizedImageReference(image)
    }

    static func normalizedImageReference(_ reference: String) -> String {
        let short = Format.shortImage(reference.trimmingCharacters(in: .whitespaces))
        let nameStart = short.lastIndex(of: "/").map { short.index(after: $0) } ?? short.startIndex
        let namePart = short[nameStart...]
        if namePart.contains(":") || namePart.contains("@") { return short }
        return short + ":latest"
    }

    @discardableResult
    mutating func adoptImageDefaults(from defaults: ContainerImageDefaults) -> Int {
        var applied = 0
        if command.trimmingCharacters(in: .whitespaces).isEmpty, !defaults.command.isEmpty {
            let cmd = defaults.command
            command = cmd.joined(separator: " ")
            applied += 1
        }
        if entrypoint.trimmingCharacters(in: .whitespaces).isEmpty,
           !defaults.entrypoint.isEmpty {
            let entrypointValue = defaults.entrypoint
            entrypoint = entrypointValue.joined(separator: " ")
            applied += 1
        }
        if workingDir.trimmingCharacters(in: .whitespaces).isEmpty,
           let workingDirValue = defaults.workingDirectory,
           !workingDirValue.isEmpty {
            workingDir = workingDirValue
            applied += 1
        }
        if user.trimmingCharacters(in: .whitespaces).isEmpty,
           let userValue = defaults.user,
           !userValue.isEmpty {
            user = userValue
            applied += 1
        }
        let existingEnvKeys = Set(env.map(\.key))
        for entry in defaults.environment {
            guard entry.isValid, !existingEnvKeys.contains(entry.key) else { continue }
            env.append(KeyValue(key: entry.key, value: entry.value))
            applied += 1
        }
        return applied
    }

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
