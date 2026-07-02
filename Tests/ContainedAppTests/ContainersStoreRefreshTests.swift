import Foundation
import Testing
import ContainedCore
@testable import Contained

@Suite("Container stats streaming")
@MainActor
struct ContainersStoreRefreshTests {
    @Test func refreshDoesNotRunStatsCommand() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = ContainerClient(runner: runner)

        await store.refresh()

        #expect(await runner.count(firstArgument: "stats") == 0)
        #expect(store.statsRevision == 0)
    }

    @Test func streamedStatsUpdateEveryFrameWithoutAppThrottle() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = ContainerClient(runner: runner)
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 1_000))
        store.now = { clock.date }

        await store.refresh()

        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.1, networkRxBytes: 10_000)], observedAt: clock.date)
        #expect(store.statsRevision == 1)

        clock.advance(by: 2)
        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.2, networkRxBytes: 11_000)], observedAt: clock.date)
        #expect(store.statsByID["fixture-web"]?.netRxBytesPerSec == 500)
        #expect(store.statsRevision == 2)

        clock.advance(by: 2)
        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.3, networkRxBytes: 12_500)], observedAt: clock.date)
        #expect(store.statsByID["fixture-web"]?.netRxBytesPerSec == 750)
        #expect(store.statsRevision == 3)
        #expect(await runner.count(firstArgument: "stats") == 0)
    }

    private static func streamedStats(cpuCoreFraction: Double, networkRxBytes: UInt64) -> RuntimeStatsSnapshot {
        RuntimeStatsSnapshot(id: "fixture-web",
                             cpuCoreFraction: cpuCoreFraction,
                             memoryUsageBytes: 2_322_432,
                             memoryLimitBytes: 1_073_741_824,
                             blockReadBytes: 2_154_496,
                             blockWriteBytes: 0,
                             networkRxBytes: networkRxBytes,
                             networkTxBytes: 516,
                             numProcesses: 1)
    }
}

private final class TestClock {
    var date: Date

    init(_ date: Date) {
        self.date = date
    }

    func advance(by seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}

private actor RecordingRunner: CommandRunning {
    private var calls: [[String]] = []
    private var statsRuns = 0

    func run(_ arguments: [String],
             stdin: Data?,
             priority: CommandExecutionPriority) async throws -> Data {
        calls.append(arguments)
        switch arguments.first {
        case "list":
            return Self.listJSON
        case "stats":
            statsRuns += 1
            return Self.statsJSON(cpuUsageUsec: UInt64(statsRuns * 1_000_000))
        default:
            return Data("[]".utf8)
        }
    }

    nonisolated func stream(_ arguments: [String], priority: CommandExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }

    func count(firstArgument: String) -> Int {
        calls.filter { $0.first == firstArgument }.count
    }

    private static let listJSON = Data("""
    [{
      "configuration": {
        "id": "fixture-web",
        "image": { "reference": "docker.io/library/alpine:latest" },
        "initProcess": {}
      },
      "id": "fixture-web",
      "status": { "state": "running" }
    }]
    """.utf8)

    private static func statsJSON(cpuUsageUsec: UInt64) -> Data {
        Data("""
        [{
          "id": "fixture-web",
          "cpuUsageUsec": \(cpuUsageUsec),
          "memoryUsageBytes": 2322432,
          "memoryLimitBytes": 1073741824,
          "networkRxBytes": \(10_000 + cpuUsageUsec / 1_000),
          "networkTxBytes": 516,
          "blockReadBytes": 2154496,
          "blockWriteBytes": 0,
          "numProcesses": 1
        }]
        """.utf8)
    }
}
