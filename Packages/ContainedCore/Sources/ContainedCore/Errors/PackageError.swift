import Foundation

/// Machine-readable error metadata for reusable packages.
///
/// Packages throw typed errors with stable codes and context. Apps decide how to
/// localize, display, alert, or record those errors.
public extension Core.Error {
protocol PackageError: Error, Sendable {
    var packageName: String { get }
    var packageErrorCode: String { get }
    var packageErrorContext: [String: String] { get }
}

}

public extension Core.Error.PackageError {
    var packageErrorContext: [String: String] { [:] }
}
