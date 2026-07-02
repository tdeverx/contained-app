import Foundation

public enum CommandExecutionPriority: Sendable {
    case userInitiated
    case utility
    case background

    var dispatchQoS: DispatchQoS.QoSClass {
        switch self {
        case .userInitiated: .userInitiated
        case .utility: .utility
        case .background: .background
        }
    }

    var qualityOfService: QualityOfService {
        switch self {
        case .userInitiated: .userInitiated
        case .utility: .utility
        case .background: .background
        }
    }
}

/// Abstraction over `container` CLI execution so stores can be tested against a mock with no daemon.
public protocol CommandRunning: Sendable {
    /// Run a command to completion. Returns stdout `Data` on success; throws `CommandError` on
    /// launch failure or non-zero exit (carrying stderr).
    func run(_ arguments: [String],
             stdin: Data?,
             priority: CommandExecutionPriority) async throws -> Data

    /// Stream a long-running command's merged stdout+stderr as it arrives. Cancelling the consuming
    /// task (or finishing the stream) terminates the child process — no leaked `logs -f`/`stats`.
    func stream(_ arguments: [String], priority: CommandExecutionPriority) -> AsyncThrowingStream<String, Error>
}

public extension CommandRunning {
    func run(_ arguments: [String]) async throws -> Data {
        try await run(arguments, stdin: nil, priority: .userInitiated)
    }

    func run(_ arguments: [String], stdin: Data?) async throws -> Data {
        try await run(arguments, stdin: stdin, priority: .userInitiated)
    }

    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        stream(arguments, priority: .userInitiated)
    }
}

/// Concrete runner backed by `Foundation.Process`.
public final class CommandRunner: CommandRunning {
    public let executableURL: URL

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }

    public func run(_ arguments: [String]) async throws -> Data {
        try await run(arguments, stdin: nil, priority: .userInitiated)
    }

    public func run(_ arguments: [String], stdin: Data?) async throws -> Data {
        try await run(arguments, stdin: stdin, priority: .userInitiated)
    }

    public func run(_ arguments: [String],
                    stdin: Data?,
                    priority: CommandExecutionPriority) async throws -> Data {
        let executableURL = self.executableURL
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: priority.dispatchQoS).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
                process.qualityOfService = priority.qualityOfService

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                let inPipe: Pipe? = stdin != nil ? Pipe() : nil
                if let inPipe { process.standardInput = inPipe }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: CommandError.launchFailed(underlying: error.localizedDescription))
                    return
                }

                // Write the secret to stdin and close it so the child sees EOF.
                if let stdin, let inPipe {
                    inPipe.fileHandleForWriting.write(stdin)
                    try? inPipe.fileHandleForWriting.close()
                }

                // Read both pipes concurrently so a full stderr buffer can't deadlock stdout.
                let outBox = DataBox()
                let errBox = DataBox()
                let group = DispatchGroup()
                let readQueue = DispatchQueue.global(qos: priority.dispatchQoS)
                group.enter()
                readQueue.async {
                    outBox.set(outPipe.fileHandleForReading.readDataToEndOfFile())
                    group.leave()
                }
                group.enter()
                readQueue.async {
                    errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile())
                    group.leave()
                }
                process.waitUntilExit()
                group.wait()

                if process.terminationStatus == 0 {
                    continuation.resume(returning: outBox.data)
                } else {
                    let stderr = String(decoding: errBox.data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: CommandError.nonZeroExit(
                        code: process.terminationStatus,
                        stderr: stderr,
                        command: arguments.joined(separator: " ")
                    ))
                }
            }
        }
    }

    public func stream(_ arguments: [String], priority: CommandExecutionPriority) -> AsyncThrowingStream<String, Error> {
        let executableURL = self.executableURL
        return AsyncThrowingStream { continuation in
            // Process/FileHandle aren't Sendable; box them so the @Sendable onTermination closure
            // (which must terminate the child on cancel) can hold a reference safely.
            let box = ProcessBox()
            let process = box.process
            process.executableURL = executableURL
            process.arguments = arguments
            process.qualityOfService = priority.qualityOfService

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            let handle = pipe.fileHandleForReading

            handle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                continuation.yield(String(decoding: data, as: UTF8.self))
            }

            process.terminationHandler = { _ in
                handle.readabilityHandler = nil
                continuation.finish()
            }

            continuation.onTermination = { _ in
                box.handle?.readabilityHandler = nil
                if box.process.isRunning { box.process.terminate() }
            }

            box.handle = handle
            DispatchQueue.global(qos: priority.dispatchQoS).async {
                do {
                    try process.run()
                } catch {
                    continuation.finish(throwing: CommandError.launchFailed(underlying: error.localizedDescription))
                }
            }
        }
    }
}

/// A Sendable holder for the non-Sendable `Process`/`FileHandle` used by `stream`'s teardown.
///
/// `@unchecked Sendable` is sound here by construction, not by the compiler's reasoning: the box is
/// only ever touched from the stream's single `onTermination`/`terminationHandler` callbacks, which
/// the Foundation runtime serializes — they never run concurrently with each other. We hand the
/// compiler the `Sendable` guarantee manually because `Process`/`FileHandle` aren't `Sendable`, but
/// the access pattern (one writer at setup, one reader at teardown) carries no data race.
private final class ProcessBox: @unchecked Sendable {
    let process = Process()
    var handle: FileHandle?
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.withLock { storage }
    }

    func set(_ data: Data) {
        lock.withLock { storage = data }
    }
}
