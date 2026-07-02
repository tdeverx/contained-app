import Testing
@testable import ContainedDesignSystem

@Suite("Live sparkline scaling")
struct LiveSparklineScalingTests {
    @Test func paddedWindowSanitizesInvalidSamples() {
        let window = SparklineSeriesScaling.paddedWindow([.nan, -1, .infinity, 2], capacity: 6)

        #expect(window == [0, 0, 0, 0, 0, 2])
    }

    @Test func normalizationClipsOneSampleOutliersWithoutFlatteningTheWindow() {
        let values = Array(repeating: 10.0, count: 23) + [1_000]
        let normalized = SparklineSeriesScaling.normalized(values)

        #expect(normalized.dropLast().allSatisfy { $0 > 0.7 })
        #expect(normalized.last == 1)
    }

    @Test func normalizationKeepsEmptySeriesFlat() {
        let normalized = SparklineSeriesScaling.normalized(Array(repeating: 0, count: 24))

        #expect(normalized.allSatisfy { $0 == 0 })
    }

    @Test func fractionScalePreservesAbsolutePercentShape() {
        let low = SparklineSeriesScaling.scaled([0.2], mode: .fraction)
        let high = SparklineSeriesScaling.scaled([0.5], mode: .fraction)

        #expect(low == [0.2])
        #expect(high == [0.5])
    }

    @Test func normalizedScaleStillExpandsSmallRateSeries() {
        let scaled = SparklineSeriesScaling.scaled([2, 4], mode: .normalized)

        #expect(scaled[0] == 0.5)
        #expect(scaled[1] == 1)
    }
}
