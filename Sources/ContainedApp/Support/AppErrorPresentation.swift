import Foundation
import ContainedCore
import ContainedRuntime

enum AppErrorPresentation {
    static func message(for error: Error) -> String {
        switch error {
        case let error as CommandError:
            return message(for: error)
        case let error as UnsupportedRuntimeCapability:
            return message(for: error)
        case let error as RegistryManifestError:
            return message(for: error)
        case let error as ComposeError:
            return message(for: error)
        case let error as LocalizedError:
            return error.errorDescription ?? (error as NSError).localizedDescription
        default:
            return (error as NSError).localizedDescription
        }
    }

    static func packageSummary(for error: Error) -> String? {
        guard let packageError = error as? ContainedPackageError else { return nil }
        let context = packageError.packageErrorContext
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(compactContextValue($0.value))" }
            .joined(separator: ", ")
        if context.isEmpty {
            return "\(packageError.packageName).\(packageError.packageErrorCode)"
        }
        return "\(packageError.packageName).\(packageError.packageErrorCode) (\(context))"
    }

    static func activityMessage(_ prefix: String, error: Error) -> String {
        let message = "\(prefix): \(message(for: error))"
        guard let summary = packageSummary(for: error) else { return message }
        return "\(message) [\(summary)]"
    }

    private static func compactContextValue(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 160 else { return collapsed }
        return "\(collapsed.prefix(157))..."
    }

    private static func message(for error: CommandError) -> String {
        switch error {
        case .cliNotFound(let searched):
            return AppText.string(
                "error.command.cliNotFound",
                defaultValue: "Couldn't find the container CLI (looked in \(searched.joined(separator: ", ")))."
            )
        case .nonZeroExit(_, let stderr, _):
            if !stderr.isEmpty { return stderr }
            return AppText.string("error.command.nonZeroExit", defaultValue: "The container command failed.")
        case .decodingFailed:
            return AppText.string(
                "error.command.decodingFailed",
                defaultValue: "Couldn't read the response from the container CLI."
            )
        case .launchFailed(let underlying):
            return AppText.string(
                "error.command.launchFailed",
                defaultValue: "Couldn't run the container CLI: \(underlying)"
            )
        }
    }

    private static func message(for error: UnsupportedRuntimeCapability) -> String {
        AppText.string(
            "error.runtime.unsupportedCapability",
            defaultValue: "The selected runtime does not support this operation."
        )
    }

    private static func message(for error: RegistryManifestError) -> String {
        switch error {
        case .invalidResponse:
            return AppText.string(
                "error.registry.invalidResponse",
                defaultValue: "The registry returned an invalid response."
            )
        case .unauthorized:
            return AppText.string(
                "error.registry.unauthorized",
                defaultValue: "The registry requires authentication."
            )
        case .notFound:
            return AppText.string("error.registry.notFound", defaultValue: "The image or tag was not found.")
        case .missingDigest:
            return AppText.string(
                "error.registry.missingDigest",
                defaultValue: "The registry response did not include a content digest."
            )
        case .httpStatus(let code):
            return AppText.string("error.registry.httpStatus", defaultValue: "The registry returned HTTP \(code).")
        case .tokenUnavailable:
            return AppText.string(
                "error.registry.tokenUnavailable",
                defaultValue: "Couldn't get a registry authorization token."
            )
        }
    }

    private static func message(for error: ComposeError) -> String {
        switch error {
        case .invalid(let reason):
            let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reason.isEmpty else { return AppText.composeInvalid }
            return AppText.composeInvalid(reason: reason)
        }
    }
}

extension Error {
    var appDisplayMessage: String {
        AppErrorPresentation.message(for: self)
    }

    var appPackageSummary: String? {
        AppErrorPresentation.packageSummary(for: self)
    }
}
