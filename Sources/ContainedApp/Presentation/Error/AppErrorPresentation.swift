import Foundation
import ContainedCore

enum AppErrorPresentation {
    static func message(for error: Error) -> String {
        switch error {
        case let error as Core.Command.Error:
            return message(for: error)
        case let error as Core.Container.RecreateFailure:
            return message(for: error)
        case let error as Core.Runtime.UnsupportedCapability:
            return message(for: error)
        case let error as Core.Registry.ManifestError:
            return message(for: error)
        case let error as Core.Compose.Error:
            return message(for: error)
        case let error as LocalizedError:
            return error.errorDescription ?? (error as NSError).localizedDescription
        default:
            return (error as NSError).localizedDescription
        }
    }

    static func packageSummary(for error: Error) -> String? {
        guard let packageError = error as? Core.Error.PackageError else { return nil }
        let context = activityContext(for: error)
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(compactContextValue($0.value))" }
            .joined(separator: ", ")
        if context.isEmpty {
            return "\(packageError.packageName).\(packageError.packageErrorCode)"
        }
        return "\(packageError.packageName).\(packageError.packageErrorCode) (\(context))"
    }

    static func activityMessage(_ prefix: String, error: Error) -> String {
        if let summary = packageSummary(for: error) {
            return "\(prefix): \(summary)"
        }
        return "\(prefix): \(String(describing: type(of: error)))"
    }

    /// Only metadata that is safe to persist in Activity or copy into support bundles.
    private static func activityContext(for error: Error) -> [String: String] {
        switch error {
        case let error as Core.Command.Error:
            if case .nonZeroExit(let code, _, _) = error {
                return ["exitCode": String(code)]
            }
            return [:]
        case let error as Core.Container.RecreateFailure:
            var context = [
                "phase": error.phase.rawValue,
                "recovery": error.recovery.rawValue,
                "primaryCode": error.primaryFailure.code,
            ]
            if let recoveryFailure = error.recoveryFailure {
                context["recoveryCode"] = recoveryFailure.code
            }
            return context
        default:
            return [:]
        }
    }

    private static func compactContextValue(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 160 else { return collapsed }
        return "\(collapsed.prefix(157))..."
    }

    private static func message(for error: Core.Command.Error) -> String {
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

    private static func message(for error: Core.Container.RecreateFailure) -> String {
        switch error.recovery {
        case .originalRestored:
            return AppText.recreateOriginalRestored(detail: error.primaryFailure.runtimeDetail)
        case .restoreFailed:
            return AppText.recreateRestoreFailed(
                replacementDetail: error.primaryFailure.runtimeDetail,
                recoveryDetail: error.recoveryFailure?.runtimeDetail ?? ""
            )
        case .notNeeded:
            return AppText.recreateFailed(detail: error.primaryFailure.runtimeDetail)
        }
    }

    private static func message(for error: Core.Runtime.UnsupportedCapability) -> String {
        AppText.string(
            "error.runtime.unsupportedCapability",
            defaultValue: "The selected runtime does not support this operation."
        )
    }

    private static func message(for error: Core.Registry.ManifestError) -> String {
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

    private static func message(for error: Core.Compose.Error) -> String {
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
