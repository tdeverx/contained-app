import Foundation
import Observation
import SwiftUI
import Synchronization
import Testing
import ContainedCore
import ContainedUI
@testable import ContainedApp

@Suite("Container stats streaming")
@MainActor
struct ContainersStoreRefreshTests {
    @Test func refreshDoesNotRunStatsCommand() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = Core.Orchestrator.testing(runner: runner,
                                                 runtimeKind: .appleContainer)

        await store.refresh()

        #expect(await runner.count(firstArgument: "stats") == 0)
        #expect(store.statsRevision == 0)
    }

    @Test func identicalRefreshSkipsInventoryPersistenceEntirely() async {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = Core.Orchestrator.testing(runner: runner,
                                                 runtimeKind: .appleContainer)

        await store.refresh()
        let preparations = database.containerInventoryPreparationCount
        let encodings = database.containerInventoryEncodedCount
        await store.refresh()

        #expect(preparations == 1)
        #expect(database.containerInventoryPreparationCount == preparations)
        #expect(database.containerInventoryEncodedCount == encodings)
    }

    @Test func dockerRefreshScopesSnapshotsAndRoutesLifecycle() async throws {
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.client = appTestOrchestrator(runner: runner,
                                           cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                           runtimeKind: .docker)

        await store.refresh()
        let snapshot = try #require(store.snapshots.first)

        #expect(snapshot.runtimeKind == .docker)
        #expect(snapshot.id == "web")
        #expect(snapshot.scopedID == "docker::web")

        await store.stop("docker::web")
        await store.start("docker::web")

        #expect(await runner.contains(["container", "stop", "web"]))
        #expect(await runner.contains(["container", "start", "web"]))
    }

    @Test func streamedStatsUpdateEveryFrameWithoutAppThrottle() async {
        let runner = RecordingRunner()
        let store = ContainersStore()
        store.client = Core.Orchestrator.testing(runner: runner,
                                                 runtimeKind: .appleContainer)
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
        store.client = Core.Orchestrator.testing(runner: runner,
                                                 runtimeKind: .appleContainer)
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

    @Test func cardChromeDoesNotObserveLiveMetricsButFooterAndGraphDo() {
        let snapshot = Self.snapshot(id: "web", cpus: 2, memoryInBytes: 1_000)
        let metrics = ContainerMetricsState(id: snapshot.scopedID)
        let renderer = ContainerCardMetricsRenderer(
            metrics: metrics,
            snapshot: snapshot,
            style: Personalization(),
            hasStyleOverride: false,
            density: .medium,
            statsNormalization: .containerSpecific,
            selectedWidgetIndex: .constant(0),
            isBusy: false,
            imageUpdateState: .unknown,
            isExpanded: false,
            controlsVisible: true,
            onTap: {},
            onStart: {},
            onStop: {},
            onRestart: {},
            onEdit: {},
            onRebuild: {},
            onDelete: {},
            onClose: {},
            onSelectMultiple: {},
            onToggleSelected: {},
            onEndSelecting: {},
            health: .unknown,
            selecting: false,
            isSelected: false
        )
        let widget = WidgetConfiguration(metric: .cpu)
        let footer = ContainerCardLiveMetricChip(metrics: metrics,
                                                 snapshot: snapshot,
                                                 widget: widget,
                                                 normalization: .containerSpecific,
                                                 isSelected: true,
                                                 tint: .blue,
                                                 action: {})
        let graph = ContainerCardLiveSparkline(metrics: metrics,
                                               widget: widget,
                                               comparisonMetric: nil,
                                               color: .blue)
        let chromeInvalidations = Mutex(0)
        let footerInvalidations = Mutex(0)
        let graphInvalidations = Mutex(0)

        withObservationTracking {
            _ = renderer.body
        } onChange: {
            chromeInvalidations.withLock { $0 += 1 }
        }
        withObservationTracking {
            _ = footer.body
        } onChange: {
            footerInvalidations.withLock { $0 += 1 }
        }
        withObservationTracking {
            _ = graph.body
        } onChange: {
            graphInvalidations.withLock { $0 += 1 }
        }

        var cpuHistory = UI.Chart.SampleBuffer()
        cpuHistory.append(0.42)
        metrics.update(stats: .sample(id: snapshot.scopedID),
                       historyByMetric: [.cpu: cpuHistory])

        #expect(chromeInvalidations.withLock { $0 } == 0)
        #expect(footerInvalidations.withLock { $0 } == 1)
        #expect(graphInvalidations.withLock { $0 } == 1)
    }

    @Test func graphMetricCaptionsUseContainerResourceLimits() {
        let snapshot = Self.snapshot(id: "web", cpus: 4, memoryInBytes: 1_024)
        let delta = Core.Metrics.StatsDelta(id: "web",
                               cpuCoreFraction: 1,
                               memoryUsageBytes: 512,
                               memoryLimitBytes: 2_048,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(Core.Metrics.GraphMetric.cpu.value(from: delta, snapshot: snapshot) == 0.25)
        #expect(Core.Metrics.GraphMetric.memory.value(from: delta, snapshot: snapshot) == 0.5)
        #expect(Core.Metrics.GraphMetric.netRx.value(from: delta, snapshot: snapshot) == 10)
        #expect(Core.Metrics.GraphMetric.netTx.value(from: delta, snapshot: snapshot) == 20)
        #expect(Core.Metrics.GraphMetric.diskRead.value(from: delta, snapshot: snapshot) == 30)
        #expect(Core.Metrics.GraphMetric.diskWrite.value(from: delta, snapshot: snapshot) == 40)
        #expect(Core.Metrics.GraphMetric.cpu.caption(from: delta, snapshot: snapshot) == "25%")
        #expect(Core.Metrics.GraphMetric.memory.caption(from: delta, snapshot: snapshot) == "50%")
        #expect(Core.Metrics.GraphMetric.cpu.chipCaption(from: delta, snapshot: snapshot) == "25%")
        #expect(Core.Metrics.GraphMetric.memory.chipCaption(from: delta, snapshot: snapshot) == "50%")
        #expect(Core.Metrics.GraphMetric.memoryLimitBytes(for: delta, snapshot: snapshot) == 1_024)
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
        let delta = Core.Metrics.StatsDelta(id: "web",
                               cpuCoreFraction: 0.032,
                               memoryUsageBytes: 4_000,
                               memoryLimitBytes: 1_000_000,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(Core.Metrics.GraphMetric.cpu.caption(from: delta, snapshot: snapshot) == "0.4%")
        #expect(Core.Metrics.GraphMetric.cpu.chipCaption(from: delta, snapshot: snapshot) == "0.4%")
        #expect(Core.Metrics.GraphMetric.memory.chipCaption(from: delta, snapshot: snapshot) == "0.4%")

        let machine = Core.Metrics.NormalizationContext(mode: .machine,
                                                machineCPUs: 16,
                                                machineMemoryBytes: 2_000_000)
        #expect(Core.Metrics.GraphMetric.cpu.chipCaption(from: delta,
                                            snapshot: snapshot,
                                            normalization: machine) == "0.2%")
        #expect(Core.Metrics.GraphMetric.memory.chipCaption(from: delta,
                                               snapshot: snapshot,
                                               normalization: machine) == "0.2%")
    }

    @Test func graphMetricCaptionsKeepTinyContainerCPUVisible() {
        let snapshot = Self.snapshot(id: "web", cpus: 4, memoryInBytes: 1_000_000)
        let delta = Core.Metrics.StatsDelta(id: "web",
                               cpuCoreFraction: 0.0012,
                               memoryUsageBytes: 4_000,
                               memoryLimitBytes: 1_000_000,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(Core.Metrics.GraphMetric.cpu.value(from: delta, snapshot: snapshot) == 0.0003)
        #expect(Core.Metrics.GraphMetric.cpu.caption(from: delta, snapshot: snapshot) == "0.03%")
        #expect(Core.Metrics.GraphMetric.cpu.chipCaption(from: delta, snapshot: snapshot) == "0.03%")
    }

    @Test func graphMetricCaptionsCanUseMachineResourceLimits() {
        let snapshot = Self.snapshot(id: "web", cpus: 4, memoryInBytes: 1_024)
        let normalization = Core.Metrics.NormalizationContext(mode: .machine,
                                                      machineCPUs: 8,
                                                      machineMemoryBytes: 4_096)
        let delta = Core.Metrics.StatsDelta(id: "web",
                               cpuCoreFraction: 1,
                               memoryUsageBytes: 512,
                               memoryLimitBytes: 2_048,
                               netRxBytesPerSec: 10,
                               netTxBytesPerSec: 20,
                               blockReadBytesPerSec: 30,
                               blockWriteBytesPerSec: 40,
                               numProcesses: 2)

        #expect(Core.Metrics.GraphMetric.cpu.value(from: delta, snapshot: snapshot, normalization: normalization) == 0.125)
        #expect(Core.Metrics.GraphMetric.memory.value(from: delta, snapshot: snapshot, normalization: normalization) == 0.125)
        #expect(Core.Metrics.GraphMetric.cpu.caption(from: delta, snapshot: snapshot, normalization: normalization) == "13%")
        #expect(Core.Metrics.GraphMetric.memory.caption(from: delta, snapshot: snapshot, normalization: normalization) == "13%")
        #expect(Core.Metrics.GraphMetric.memoryLimitBytes(for: delta, snapshot: snapshot, normalization: normalization) == 4_096)
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

        #expect(Core.Metrics.GraphMetric.cpu.value(from: sample, snapshot: snapshot) == 0.25)
        #expect(Core.Metrics.GraphMetric.memory.value(from: sample, snapshot: snapshot, memoryFallbackBytes: 2_048) == 0.5)
        #expect(Core.Metrics.GraphMetric.netRx.value(from: sample, snapshot: snapshot) == 10)
        #expect(Core.Metrics.GraphMetric.diskWrite.value(from: sample, snapshot: snapshot) == 40)

        let machine = Core.Metrics.NormalizationContext(mode: .machine,
                                                machineCPUs: 8,
                                                machineMemoryBytes: 4_096)
        #expect(Core.Metrics.GraphMetric.cpu.value(from: sample, snapshot: snapshot, normalization: machine) == 0.125)
        #expect(Core.Metrics.GraphMetric.memory.value(from: sample,
                                         snapshot: snapshot,
                                         normalization: machine,
                                         memoryFallbackBytes: 2_048) == 0.125)
    }

    @Test func historyChartPointsUsePlainSamplesWithCurrentNormalization() {
        let snapshot = Self.snapshot(id: "web", cpus: 2, memoryInBytes: 0)
        let samples = [
            MetricSample(timestamp: Date(timeIntervalSinceReferenceDate: 1_000),
                         containerID: "web",
                         cpuFraction: 1,
                         memoryBytes: 512,
                         netRxBytesPerSec: 1_024,
                         netTxBytesPerSec: 2_048,
                         diskReadBytesPerSec: 3_072,
                         diskWriteBytesPerSec: 4_096),
            MetricSample(timestamp: Date(timeIntervalSinceReferenceDate: 1_060),
                         containerID: "web",
                         cpuFraction: 0.5,
                         memoryBytes: 1_024,
                         netRxBytesPerSec: 2_048,
                         netTxBytesPerSec: 4_096,
                         diskReadBytesPerSec: 5_120,
                         diskWriteBytesPerSec: 6_144)
        ].map(MetricSampleSnapshot.init)

        let containerPoints = HistoryChartPoint.points(from: samples,
                                                       snapshot: snapshot,
                                                       normalization: .containerSpecific)
        #expect(containerPoints.map { $0.cpuPercent } == [50, 25])
        #expect(containerPoints.map { $0.memoryPercent } == [50, 100])
        #expect(containerPoints.map { $0.netRxKBPerSec } == [1, 2])
        #expect(containerPoints.map { $0.netTxKBPerSec } == [2, 4])
        #expect(containerPoints.map { $0.diskReadKBPerSec } == [3, 5])
        #expect(containerPoints.map { $0.diskWriteKBPerSec } == [4, 6])

        let machine = Core.Metrics.NormalizationContext(mode: .machine,
                                                machineCPUs: 4,
                                                machineMemoryBytes: 2_048)
        let machinePoints = HistoryChartPoint.points(from: samples,
                                                     snapshot: snapshot,
                                                     normalization: machine)
        #expect(machinePoints.map { $0.cpuPercent } == [25, 12.5])
        #expect(machinePoints.map { $0.memoryPercent } == [25, 50])
    }

    @Test func historyChartDownsamplingBoundsRenderedMarks() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var samples: [MetricSampleSnapshot] = []
        for offset in 0..<1_201 {
            let value = Double(offset)
            let sample = MetricSampleSnapshot(timestamp: start.addingTimeInterval(value),
                                              containerID: "web",
                                              cpuFraction: value,
                                              memoryBytes: value,
                                              netRxBytesPerSec: value,
                                              netTxBytesPerSec: value,
                                              diskReadBytesPerSec: value,
                                              diskWriteBytesPerSec: value)
            samples.append(sample)
        }

        let downsampled = HistoryChartPoint.downsample(samples, maximumPoints: 120)

        #expect(downsampled.count == 120)
        #expect(downsampled.first!.timestamp >= samples.first!.timestamp)
        #expect(downsampled.last!.timestamp <= samples.last!.timestamp)
    }

    @Test func historyChartDownsamplingPreservesShortPeaksAndLows() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let samples = (0..<100).map { offset in
            let isPeak = offset == 47
            return MetricSampleSnapshot(timestamp: start.addingTimeInterval(Double(offset)),
                                        containerID: "web",
                                        cpuFraction: isPeak ? 100 : 1,
                                        memoryBytes: isPeak ? 100 : 1,
                                        netRxBytesPerSec: isPeak ? 100 : 1,
                                        netTxBytesPerSec: isPeak ? 100 : 1,
                                        diskReadBytesPerSec: isPeak ? 100 : 1,
                                        diskWriteBytesPerSec: isPeak ? 100 : 1)
        }

        let downsampled = HistoryChartPoint.downsample(samples, maximumPoints: 20)

        #expect(downsampled.count <= 20)
        #expect(downsampled.contains { $0.cpuFraction == 100 })
        #expect(downsampled.contains { $0.cpuFraction == 1 })
    }

    @Test func sevenDayDownsamplingDoesNotTurnContinuousHistoryIntoSinglePointSegments() {
        let snapshot = Self.snapshot(id: "web", cpus: 1, memoryInBytes: 1)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let samples = (0..<1_201).map { offset in
            MetricSampleSnapshot(timestamp: start.addingTimeInterval(Double(offset) * 8 * 60),
                                 containerID: snapshot.scopedID,
                                 cpuFraction: 0.2,
                                 memoryBytes: 1,
                                 netRxBytesPerSec: 2,
                                 netTxBytesPerSec: 3,
                                 diskReadBytesPerSec: 4,
                                 diskWriteBytesPerSec: 5)
        }

        let points = HistoryChartPoint.points(from: samples,
                                              snapshot: snapshot,
                                              normalization: .containerSpecific)

        #expect(points.count == HistoryChartPoint.maximumRenderedPoints)
        #expect(Set(points.map(\.segment)) == [0])
    }

    @Test func historyPercentageScaleRoundsToTheNextUsefulMagnitude() {
        #expect(HistoryPercentScale(values: []).upperBound == 1)
        #expect(HistoryPercentScale(values: [0.04]).upperBound == 0.05)
        #expect(HistoryPercentScale(values: [0.8]).upperBound == 1)
        #expect(HistoryPercentScale(values: [8]).upperBound == 10)
        #expect(HistoryPercentScale(values: [36]).upperBound == 50)
        #expect(HistoryPercentScale(values: [99, .infinity, .nan]).upperBound == 100)
        #expect(HistoryPercentScale(values: [140]).upperBound == 100)
        #expect(HistoryValueScale(values: [620]).upperBound == 1_000)
    }

    @Test func scrollableHistoryWindowsStayBounded() {
        let latest = Date(timeIntervalSince1970: 12 * 3_600 + 47 * 60)
        #expect(HistoryTimeline.initialScrollPosition(latest: latest, viewport: .oneHour)
            == Date(timeIntervalSince1970: 11 * 3_600 + 47 * 60))
        #expect(HistoryTimeline.initialScrollPosition(latest: latest, viewport: .sixHours)
            == Date(timeIntervalSince1970: 6 * 3_600 + 47 * 60))
        #expect(HistoryViewport.allCases.map(\.rawValue) == [1, 6, 12, 24])

        let snapshot = Self.snapshot(id: "web", cpus: 1, memoryInBytes: 1)
        var samples: [MetricSampleSnapshot] = []
        for hour in 0..<10 {
            let value = Double(hour)
            let timestamp = Date(timeIntervalSince1970: value * 3_600)
            samples.append(MetricSampleSnapshot(timestamp: timestamp,
                                                containerID: snapshot.scopedID,
                                                cpuFraction: value,
                                                memoryBytes: value,
                                                netRxBytesPerSec: value,
                                                netTxBytesPerSec: value,
                                                diskReadBytesPerSec: value,
                                                diskWriteBytesPerSec: value))
        }
        let points = HistoryChartPoint.points(from: samples,
                                              snapshot: snapshot,
                                              normalization: .containerSpecific,
                                              maximumPoints: samples.count)
        let position = Date(timeIntervalSince1970: 5 * 3_600)
        #expect(HistoryTimeline.visiblePoints(in: points, from: position, viewport: .oneHour).count == 2)
        #expect(HistoryTimeline.points(in: points,
                                      range: HistoryTimeline.bufferedRange(around: position,
                                                                           viewport: .oneHour)).count == 4)
    }

    @Test func historyChartBreaksLinesAfterLongSamplingGap() {
        let snapshot = Self.snapshot(id: "web", cpus: 1, memoryInBytes: 1)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let samples = [
            MetricSampleSnapshot(timestamp: start, containerID: "apple-container::web", cpuFraction: 0,
                                  memoryBytes: 0, netRxBytesPerSec: 0, netTxBytesPerSec: 0,
                                  diskReadBytesPerSec: 0, diskWriteBytesPerSec: 0),
            MetricSampleSnapshot(timestamp: start.addingTimeInterval(HistoryChartPoint.maximumContinuousGap + 1),
                                  containerID: "apple-container::web", cpuFraction: 0,
                                  memoryBytes: 0, netRxBytesPerSec: 0, netTxBytesPerSec: 0,
                                  diskReadBytesPerSec: 0, diskWriteBytesPerSec: 0)
        ]

        #expect(HistoryChartPoint.points(from: samples,
                                         snapshot: snapshot,
                                         normalization: .containerSpecific).map(\.segment) == [0, 1])
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

        store.configureStatsNormalization(Core.Metrics.NormalizationContext(mode: .machine,
                                                                    machineCPUs: 4,
                                                                    machineMemoryBytes: 2_000))

        #expect(metrics.values(for: .cpu) == [0.25])
        #expect(metrics.values(for: .memory) == [0.25])
    }

    private static func streamedStats(cpuCoreFraction: Double, networkRxBytes: UInt64) -> Core.Metrics.RuntimeStatsSnapshot {
        streamedStats(id: "fixture-web",
                      cpuCoreFraction: cpuCoreFraction,
                      memoryUsageBytes: 2_322_432,
                      networkRxBytes: networkRxBytes)
    }

    private static func streamedStats(id: String,
                                      cpuCoreFraction: Double,
                                      memoryUsageBytes: UInt64,
                                      memoryLimitBytes: UInt64 = 1_073_741_824,
                                      networkRxBytes: UInt64) -> Core.Metrics.RuntimeStatsSnapshot {
        Core.Metrics.RuntimeStatsSnapshot(id: id,
                             cpuCoreFraction: cpuCoreFraction,
                             memoryUsageBytes: memoryUsageBytes,
                             memoryLimitBytes: memoryLimitBytes,
                             blockReadBytes: 2_154_496,
                             blockWriteBytes: 0,
                             networkRxBytes: networkRxBytes,
                             networkTxBytes: 516,
                             numProcesses: 1)
    }

    private static func snapshot(id: String, cpus: Int, memoryInBytes: UInt64) -> Core.Container.Snapshot {
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
        return try! Core.Container.JSON.decode(Core.Container.Snapshot.self,
                                               from: Data(payload.utf8),
                                               runtimeKind: .appleContainer)
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

private actor RecordingRunner: Core.Command.Running {
    private var calls: [[String]] = []
    private var statsRuns = 0

    func run(_ arguments: [String],
             stdin: Data?,
             priority: Core.Command.ExecutionPriority) async throws -> Data {
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

    nonisolated func stream(_ arguments: [String], priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
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

actor DockerRecordingRunner: Core.Command.Running {
    private var calls: [[String]] = []

    func run(_ arguments: [String],
             stdin: Data?,
             priority: Core.Command.ExecutionPriority) async throws -> Data {
        calls.append(arguments)
        if arguments == ["container", "ls", "--all", "--no-trunc", "--quiet"] {
            return Data("0123456789abcdef\n".utf8)
        }
        if arguments == ["container", "inspect", "0123456789abcdef"] {
            return Self.inspectJSON
        }
        return Data()
    }

    nonisolated func stream(_ arguments: [String],
                            priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }

    func contains(_ arguments: [String]) -> Bool {
        calls.contains(arguments)
    }

    private static let inspectJSON = Data("""
    [
      {
        "Id": "0123456789abcdef",
        "Name": "/web",
        "Platform": "linux/arm64",
        "Config": {
          "Image": "nginx:latest",
          "Cmd": ["nginx", "-g", "daemon off;"],
          "Env": [],
          "Labels": {},
          "Tty": false
        },
        "State": {
          "Status": "running",
          "Running": true,
          "StartedAt": "2026-07-03T09:31:00Z"
        },
        "HostConfig": {
          "PortBindings": {},
          "ReadonlyRootfs": false,
          "Init": false
        },
        "NetworkSettings": {
          "Networks": {}
        },
        "Mounts": []
      }
    ]
    """.utf8)
}
