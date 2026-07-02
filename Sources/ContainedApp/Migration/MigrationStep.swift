import Foundation

protocol MigrationStep {
    var fromVersion: Int { get }
    var toVersion: Int { get }
    func upgrade(_ section: JSONValue, named name: AppStateSection) throws -> JSONValue
    func downgrade(_ section: JSONValue, named name: AppStateSection) throws -> JSONValue
}

extension MigrationStep {
    func upgrade(_ section: JSONValue, named name: AppStateSection) throws -> JSONValue { section }
    func downgrade(_ section: JSONValue, named name: AppStateSection) throws -> JSONValue { section }
}

enum MigrationError: LocalizedError {
    case missingDowngradeStep(from: Int, to: Int)
    case unsupportedFutureSchema(Int)

    var errorDescription: String? {
        switch self {
        case .missingDowngradeStep(let from, let to):
            return "No downgrade path exists from schema \(from) to \(to)."
        case .unsupportedFutureSchema(let version):
            return "This data was created by a newer Contained schema (\(version))."
        }
    }
}
