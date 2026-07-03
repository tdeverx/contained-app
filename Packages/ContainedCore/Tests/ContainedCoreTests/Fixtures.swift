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

/// A `Core.Command.Running` that replays canned output/errors with no runtime daemon.
struct MockCommandRunner: Core.Command.Running {
    var result: Result<Data, Core.Command.Error>
    var streamChunks: [String] = []

    func run(_ arguments: [String],
             stdin: Data?,
             priority: Core.Command.ExecutionPriority) async throws -> Data {
        try result.get()
    }

    func stream(_ arguments: [String],
                priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        let chunks = streamChunks
        return AsyncThrowingStream { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}
