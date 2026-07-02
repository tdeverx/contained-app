import Foundation
import Testing
@testable import ContainedCore

/// Loads a captured CLI fixture from the test bundle.
enum Fixture {
    static func data(_ name: String, ext: String = "json") throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
            throw FixtureError.notFound("\(name).\(ext)")
        }
        return try Data(contentsOf: url)
    }

    static func string(_ name: String, ext: String = "txt") throws -> String {
        String(decoding: try data(name, ext: ext), as: UTF8.self)
    }

    enum FixtureError: Error { case notFound(String) }
}
