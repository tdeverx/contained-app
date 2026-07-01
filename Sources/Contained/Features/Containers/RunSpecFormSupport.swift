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

    func matchingImage(in images: [ContainedCore.ImageResource]) -> ContainedCore.ImageResource? {
        let target = normalizedImageReference
        return images.first { Self.normalizedImageReference($0.reference) == target }
    }

    func imageDefaults(in images: [ContainedCore.ImageResource]) -> VariantConfig.OCIConfig? {
        matchingImage(in: images).flatMap { imageDefaults(from: $0) }
    }

    func imageDefaults(from image: ContainedCore.ImageResource) -> VariantConfig.OCIConfig? {
        let runnable = image.variants.filter(\.isRunnable)
        let platformMatch = runnable.first { variant in
            !platform.isEmpty && variant.platform.display == platform
        }
        #if arch(arm64)
        let hostMatch = runnable.first { $0.platform.os == "linux" && $0.platform.architecture == "arm64" }
        #else
        let hostMatch = runnable.first { $0.platform.os == "linux" && $0.platform.architecture == "amd64" }
        #endif
        return (platformMatch ?? hostMatch ?? runnable.first)?.config?.config
    }

    @discardableResult
    mutating func adoptImageDefaults(from config: VariantConfig.OCIConfig) -> Int {
        var applied = 0
        if command.trimmingCharacters(in: .whitespaces).isEmpty, let cmd = config.cmd, !cmd.isEmpty {
            command = cmd.joined(separator: " ")
            applied += 1
        }
        if entrypoint.trimmingCharacters(in: .whitespaces).isEmpty,
           let entrypointValue = config.entrypoint,
           !entrypointValue.isEmpty {
            entrypoint = entrypointValue.joined(separator: " ")
            applied += 1
        }
        if workingDir.trimmingCharacters(in: .whitespaces).isEmpty,
           let workingDirValue = config.workingDir,
           !workingDirValue.isEmpty {
            workingDir = workingDirValue
            applied += 1
        }
        if user.trimmingCharacters(in: .whitespaces).isEmpty,
           let userValue = config.user,
           !userValue.isEmpty {
            user = userValue
            applied += 1
        }
        let existingEnvKeys = Set(env.map(\.key))
        for entry in config.env ?? [] {
            guard let separator = entry.firstIndex(of: "=") else { continue }
            let key = String(entry[..<separator])
            guard !key.isEmpty, !existingEnvKeys.contains(key) else { continue }
            let value = String(entry[entry.index(after: separator)...])
            env.append(KeyValue(key: key, value: value))
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
