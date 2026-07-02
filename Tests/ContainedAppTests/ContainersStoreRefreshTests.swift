import Foundation
import Testing
import ContainedCore
@testable import Contained

@Suite("Container stats refresh cadence")
@MainActor
struct ContainersStoreRefreshTests {
    @Test func visibleStatsAreSampledNoMoreThanEveryTenSeconds() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = ContainerClient(runner: runner)
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 1_000))
        store.now = { clock.date }

        await store.refresh(statsDemand: .visible)
        #expect(await runner.count(firstArgument: "stats") == 1)
        #expect(store.statsRevision == 0)

        await store.refresh(statsDemand: .visible)
        #expect(await runner.count(firstArgument: "stats") == 1)

        clock.advance(by: 9)
        await store.refresh(statsDemand: .visible)
        #expect(await runner.count(firstArgument: "stats") == 1)

        clock.advance(by: 1)
        await store.refresh(statsDemand: .visible)
        #expect(await runner.count(firstArgument: "stats") == 2)
        #expect(store.statsRevision == 1)
    }

    @Test func backgroundStatsUseLongerCadence() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = ContainerClient(runner: runner)
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 2_000))
        store.now = { clock.date }

        await store.refresh(statsDemand: .background)
        #expect(await runner.count(firstArgument: "stats") == 1)

        clock.advance(by: 29)
        await store.refresh(statsDemand: .background)
        #expect(await runner.count(firstArgument: "stats") == 1)

        clock.advance(by: 1)
        await store.refresh(statsDemand: .background)
        #expect(await runner.count(firstArgument: "stats") == 2)
    }

    @Test func forcedStatsBypassCadence() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = ContainerClient(runner: runner)
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 3_000))
        store.now = { clock.date }

        await store.refresh(statsDemand: .visible)
        await store.refresh(statsDemand: .force)

        #expect(await runner.count(firstArgument: "stats") == 2)
        #expect(store.statsRevision == 1)
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

    func run(_ arguments: [String]) async throws -> Data {
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

    nonisolated func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
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
