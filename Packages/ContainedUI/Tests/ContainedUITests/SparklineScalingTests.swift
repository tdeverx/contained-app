import Testing
import CoreGraphics
@testable import ContainedUI

@Suite("Live sparkline scaling")
struct SparklineScalingTests {
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

    @Test func canvasGeometryCapsAndBoundsEveryInterpolation() {
        let values = (0..<80).map { Double($0 % 13) }
        let series = SparklineGeometry.series(values, scale: .normalized, capacity: 24)
        let points = SparklineGeometry.points(series, in: CGSize(width: 240, height: 60), capacity: 24)

        #expect(series.count == 24)
        #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        #expect(points.allSatisfy { (0...240).contains($0.x) && (0...60).contains($0.y) })
        for interpolation in UI.Chart.Interpolation.allCases {
            let bounds = SparklineGeometry.path(points, interpolation: interpolation).boundingRect
            #expect(bounds.origin.x.isFinite)
            #expect(bounds.origin.y.isFinite)
            #expect(bounds.width.isFinite)
            #expect(bounds.height.isFinite)
        }
    }

    @Test func secondarySeriesRemainRightAligned() {
        let primary = SparklineGeometry.series([1, 2, 3], scale: .normalized, capacity: 24)
        let secondary = SparklineGeometry.series([4, 5], scale: .normalized, capacity: 24)

        #expect(primary.map(\.index) == [21, 22, 23])
        #expect(secondary.map(\.index) == [22, 23])
    }
}
