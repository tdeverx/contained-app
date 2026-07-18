import Foundation

public extension Core.Container {
    /// Describes which destructive recreate phase failed and whether Core restored the original.
    struct RecreateFailure: Error, Equatable, Sendable {
        public enum Phase: String, Equatable, Sendable {
            case deleteOriginal
            case createReplacement
            case restoreOriginal
        }

        public enum Recovery: String, Equatable, Sendable {
            case notNeeded
            case originalRestored
            case restoreFailed
        }

        public struct Cause: Equatable, Sendable {
            public let packageName: String
            public let code: String
            /// Runtime detail for immediate presentation. This must not be persisted or logged.
            public let runtimeDetail: String

            init(_ error: Error) {
                if let packageError = error as? Core.Error.PackageError {
                    packageName = packageError.packageName
                    code = packageError.packageErrorCode
                } else {
                    packageName = "ContainedCore"
                    code = String(describing: type(of: error))
                }
                runtimeDetail = Self.runtimeDetail(for: error)
            }

            private static func runtimeDetail(for error: Error) -> String {
                switch error {
                case let error as Core.Command.Error:
                    switch error {
                    case .cliNotFound(let searched):
                        return searched.joined(separator: ", ")
                    case .nonZeroExit(_, let stderr, _):
                        return stderr
                    case .decodingFailed(let underlying, _), .launchFailed(let underlying):
                        return underlying
                    }
                case let error as LocalizedError:
                    return error.errorDescription ?? String(describing: error)
                default:
                    return String(describing: error)
                }
            }
        }

        public let phase: Phase
        public let recovery: Recovery
        public let primaryFailure: Cause
        public let recoveryFailure: Cause?

        init(phase: Phase,
             recovery: Recovery,
             primaryError: Error,
             recoveryError: Error? = nil) {
            self.phase = phase
            self.recovery = recovery
            primaryFailure = Cause(primaryError)
            recoveryFailure = recoveryError.map(Cause.init)
        }
    }
}

extension Core.Container.RecreateFailure: Core.Error.PackageError {
    public var packageName: String { "ContainedCore" }
    public var packageErrorCode: String { "containerRecreateFailed" }

    /// Deliberately allowlisted: runtime detail may contain commands, paths, or secrets.
    public var packageErrorContext: [String: String] {
        var context = [
            "phase": phase.rawValue,
            "recovery": recovery.rawValue,
            "primaryCode": primaryFailure.code,
        ]
        if let recoveryFailure {
            context["recoveryCode"] = recoveryFailure.code
        }
        return context
    }
}
