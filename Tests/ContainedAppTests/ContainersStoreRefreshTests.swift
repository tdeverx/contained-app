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
        let metrics = store.metricsState(for: "fixture-web")

        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.1, networkRxBytes: 10_000)], observedAt: clock.date)
        #expect(store.statsRevision == 1)
        #expect(metrics.revision == 1)

        clock.advance(by: 2)
        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.2, networkRxBytes: 11_000)], observedAt: clock.date)
        #expect(store.statsByID["fixture-web"]?.netRxBytesPerSec == 500)
        #expect(metrics.stats?.netRxBytesPerSec == 500)
        #expect(metrics.values(for: .netRx).last == 500)
        #expect(store.statsRevision == 2)
        #expect(metrics.revision == 2)

        clock.advance(by: 2)
        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.3, networkRxBytes: 12_500)], observedAt: clock.date)
        #expect(store.statsByID["fixture-web"]?.netRxBytesPerSec == 750)
        #expect(metrics.stats?.netRxBytesPerSec == 750)
        #expect(metrics.values(for: .netRx).last == 750)
        #expect(store.statsRevision == 3)
        #expect(metrics.revision == 3)
        #expect(await runner.count(firstArgument: "stats") == 0)
    }

    @Test func streamedStatsClampTinyIntervalsForCounterRates() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = ContainerClient(runner: runner)
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 1_000))
        store.now = { clock.date }

        await store.refresh()
        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.1, networkRxBytes: 10_000)], observedAt: clock.date)

        clock.advance(by: 0.05)
        store.applyStreamedStats([Self.streamedStats(cpuCoreFraction: 0.1, networkRxBytes: 11_000)], observedAt: clock.date)

        #expect(store.statsByID["fixture-web"]?.netRxBytesPerSec == 1_000)
        #expect(store.metricsState(for: "fixture-web").values(for: .netRx).last == 1_000)
    }

    @Test func streamedStatsKeepHistoriesKeyedByContainerAndMetric() {
        let store = ContainersStore()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        store.snapshots = [
            Self.snapshot(id: "web", cpus: 2, memoryInBytes: 1_000),
            Self.snapshot(id: "db", cpus: 4, memoryInBytes: 2_000)
        ]
        let webMetrics = store.metricsState(for: "web")
        let dbMetrics = store.metricsState(for: "db")

        store.applyStreamedStats([
            Self.streamedStats(id: "web", cpuCoreFraction: 0.5, memoryUsageBytes: 100,
                               memoryLimitBytes: 1_000, networkRxBytes: 1_000),
            Self.streamedStats(id: "db", cpuCoreFraction: 1.0, memoryUsageBytes: 400,
                               memoryLimitBytes: 1_000, networkRxBytes: 2_000)
        ], observedAt: start)
        store.applyStreamedStats([
            Self.streamedStats(id: "web", cpuCoreFraction: 1.0, memoryUsageBytes: 500,
                               memoryLimitBytes: 1_000, networkRxBytes: 3_000),
            Self.streamedStats(id: "db", cpuCoreFraction: 1.0, memoryUsageBytes: 500,
                               memoryLimitBytes: 1_000, networkRxBytes: 2_600)
        ], observedAt: start.addingTimeInterval(2))

        #expect(webMetrics.stats?.id == "web")
        #expect(dbMetrics.stats?.id == "db")
        #expect(webMetrics.values(for: .cpu).last == 0.5)
        #expect(dbMetrics.values(for: .cpu).last == 0.25)
        #expect(webMetrics.values(for: .memory).last == 0.5)
        #expect(dbMetrics.values(for: .memory).last == 0.25)
        #expect(webMetrics.values(for: .netRx).last == 1_000)
        #expect(dbMetrics.values(for: .netRx).last == 300)
    }

    @Test func graphMetricCaptionsUseContainerResourceLimits() {
        let snapshot = Self.snapshot(id: "web", cpus: 4, memoryInBytes: 1_024)
        let delta = StatsDelta(id: "web",
                               cpuCoreFraction: 1,
                               memoryUsageBytes: 512,
                               memoryLimitBytes: 2_048,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(GraphMetric.cpu.value(from: delta, snapshot: snapshot) == 0.25)
        #expect(GraphMetric.memory.value(from: delta, snapshot: snapshot) == 0.5)
        #expect(GraphMetric.netRx.value(from: delta, snapshot: snapshot) == 10)
        #expect(GraphMetric.netTx.value(from: delta, snapshot: snapshot) == 20)
        #expect(GraphMetric.diskRead.value(from: delta, snapshot: snapshot) == 30)
        #expect(GraphMetric.diskWrite.value(from: delta, snapshot: snapshot) == 40)
        #expect(GraphMetric.cpu.caption(from: delta, snapshot: snapshot) == "25%")
        #expect(GraphMetric.memory.caption(from: delta, snapshot: snapshot) == "50%")
        #expect(GraphMetric.cpu.chipCaption(from: delta, snapshot: snapshot) == "25%")
        #expect(GraphMetric.memory.chipCaption(from: delta, snapshot: snapshot) == "50%")
        #expect(GraphMetric.memoryLimitBytes(for: delta, snapshot: snapshot) == 1_024)
    }

    @Test func percentFormattingUsesDecimalsOnlyWhenUseful() {
        #expect(Format.percent(0) == "0%")
        #expect(Format.percent(0.00003) == "<0.01%")
        #expect(Format.percent(0.0003) == "0.03%")
        #expect(Format.percent(0.004) == "0.4%")
        #expect(Format.percent(0.0125) == "1%")
        #expect(Format.percent(0.125) == "13%")
        #expect(Format.percent(0.25) == "25%")
    }

    @Test func graphMetricChipCaptionsExposeSmallPercentChanges() {
        let snapshot = Self.snapshot(id: "web", cpus: 8, memoryInBytes: 1_000_000)
        let delta = StatsDelta(id: "web",
                               cpuCoreFraction: 0.032,
                               memoryUsageBytes: 4_000,
                               memoryLimitBytes: 1_000_000,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(GraphMetric.cpu.caption(from: delta, snapshot: snapshot) == "0.4%")
        #expect(GraphMetric.cpu.chipCaption(from: delta, snapshot: snapshot) == "0.4%")
        #expect(GraphMetric.memory.chipCaption(from: delta, snapshot: snapshot) == "0.4%")

        let machine = StatsNormalizationContext(mode: .machine,
                                                machineCPUs: 16,
                                                machineMemoryBytes: 2_000_000)
        #expect(GraphMetric.cpu.chipCaption(from: delta,
                                            snapshot: snapshot,
                                            normalization: machine) == "0.2%")
        #expect(GraphMetric.memory.chipCaption(from: delta,
                                               snapshot: snapshot,
                                               normalization: machine) == "0.2%")
    }

    @Test func graphMetricCaptionsKeepTinyContainerCPUVisible() {
        let snapshot = Self.snapshot(id: "web", cpus: 4, memoryInBytes: 1_000_000)
        let delta = StatsDelta(id: "web",
                               cpuCoreFraction: 0.0012,
                               memoryUsageBytes: 4_000,
                               memoryLimitBytes: 1_000_000,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(GraphMetric.cpu.value(from: delta, snapshot: snapshot) == 0.0003)
        #expect(GraphMetric.cpu.caption(from: delta, snapshot: snapshot) == "0.03%")
        #expect(GraphMetric.cpu.chipCaption(from: delta, snapshot: snapshot) == "0.03%")
    }

    @Test func graphMetricCaptionsCanUseMachineResourceLimits() {
        let snapshot = Self.snapshot(id: "web", cpus: 4, memoryInBytes: 1_024)
        let normalization = StatsNormalizationContext(mode: .machine,
                                                      machineCPUs: 8,
                                                      machineMemoryBytes: 4_096)
        let delta = StatsDelta(id: "web",
                               cpuCoreFraction: 1,
                               memoryUsageBytes: 512,
                               memoryLimitBytes: 2_048,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(GraphMetric.cpu.value(from: delta, snapshot: snapshot, normalization: normalization) == 0.125)
        #expect(GraphMetric.memory.value(from: delta, snapshot: snapshot, normalization: normalization) == 0.125)
        #expect(GraphMetric.cpu.caption(from: delta, snapshot: snapshot, normalization: normalization) == "13%")
        #expect(GraphMetric.memory.caption(from: delta, snapshot: snapshot, normalization: normalization) == "13%")
        #expect(GraphMetric.memoryLimitBytes(for: delta, snapshot: snapshot, normalization: normalization) == 4_096)
    }

    @Test func graphMetricHistoryValuesUseCurrentNormalization() {
        let snapshot = Self.snapshot(id: "web", cpus: 4, memoryInBytes: 1_024)
        let sample = MetricSample(timestamp: Date(timeIntervalSinceReferenceDate: 1_000),
                                  containerID: "web",
                                  cpuFraction: 1,
                                  memoryBytes: 512,
                                  netRxBytesPerSec: 10,
                                  netTxBytesPerSec: 20,
                                  diskReadBytesPerSec: 30,
                                  diskWriteBytesPerSec: 40)

        #expect(GraphMetric.cpu.value(from: sample, snapshot: snapshot) == 0.25)
        #expect(GraphMetric.memory.value(from: sample, snapshot: snapshot, memoryFallbackBytes: 2_048) == 0.5)
        #expect(GraphMetric.netRx.value(from: sample, snapshot: snapshot) == 10)
        #expect(GraphMetric.diskWrite.value(from: sample, snapshot: snapshot) == 40)

        let machine = StatsNormalizationContext(mode: .machine,
                                                machineCPUs: 8,
                                                machineMemoryBytes: 4_096)
        #expect(GraphMetric.cpu.value(from: sample, snapshot: snapshot, normalization: machine) == 0.125)
        #expect(GraphMetric.memory.value(from: sample,
                                         snapshot: snapshot,
                                         normalization: machine,
                                         memoryFallbackBytes: 2_048) == 0.125)
    }

    @Test func changingStatsNormalizationRebuildsDisplayHistories() {
        let store = ContainersStore()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        store.snapshots = [
            Self.snapshot(id: "web", cpus: 2, memoryInBytes: 1_000)
        ]
        let metrics = store.metricsState(for: "web")

        store.applyStreamedStats([
            Self.streamedStats(id: "web", cpuCoreFraction: 1, memoryUsageBytes: 500,
                               memoryLimitBytes: 1_000, networkRxBytes: 1_000)
        ], observedAt: start)
        #expect(metrics.values(for: .cpu).last == 0.5)
        #expect(metrics.values(for: .memory).last == 0.5)

        store.configureStatsNormalization(StatsNormalizationContext(mode: .machine,
                                                                    machineCPUs: 4,
                                                                    machineMemoryBytes: 2_000))

        #expect(metrics.values(for: .cpu) == [0.25])
        #expect(metrics.values(for: .memory) == [0.25])
    }

    private static func streamedStats(cpuCoreFraction: Double, networkRxBytes: UInt64) -> RuntimeStatsSnapshot {
        streamedStats(id: "fixture-web",
                      cpuCoreFraction: cpuCoreFraction,
                      memoryUsageBytes: 2_322_432,
                      networkRxBytes: networkRxBytes)
    }

    private static func streamedStats(id: String,
                                      cpuCoreFraction: Double,
                                      memoryUsageBytes: UInt64,
                                      memoryLimitBytes: UInt64 = 1_073_741_824,
                                      networkRxBytes: UInt64) -> RuntimeStatsSnapshot {
        RuntimeStatsSnapshot(id: id,
                             cpuCoreFraction: cpuCoreFraction,
                             memoryUsageBytes: memoryUsageBytes,
                             memoryLimitBytes: memoryLimitBytes,
                             blockReadBytes: 2_154_496,
                             blockWriteBytes: 0,
                             networkRxBytes: networkRxBytes,
                             networkTxBytes: 516,
                             numProcesses: 1)
    }

    private static func snapshot(id: String, cpus: Int, memoryInBytes: UInt64) -> ContainerSnapshot {
        let payload = """
        {
          "configuration": {
            "id": "\(id)",
            "image": { "reference": "docker.io/library/alpine:latest" },
            "initProcess": {},
            "resources": {
              "cpus": \(cpus),
              "memoryInBytes": \(memoryInBytes)
            }
          },
          "id": "\(id)",
          "status": { "state": "running" }
        }
        """
        return try! JSONDecoder().decode(ContainerSnapshot.self, from: Data(payload.utf8))
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
