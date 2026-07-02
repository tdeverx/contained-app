import CoreGraphics
import Testing
@testable import ContainedNavigation

@Suite("Single surface morph geometry")
struct MorphingSingleSurfaceTests {
    @Test func interpolatesBetweenSourceAndTarget() {
        let source = CGRect(x: 10, y: 20, width: 100, height: 60)
        let target = CGRect(x: 40, y: 80, width: 220, height: 300)

        let rect = source.morphInterpolated(to: target, progress: 0.25)

        #expect(rect.minX == 17.5)
        #expect(rect.minY == 35)
        #expect(rect.width == 130)
        #expect(rect.height == 120)
    }

    @Test func clampsInvalidProgress() {
        let source = CGRect(x: 0, y: 0, width: 20, height: 20)
        let target = CGRect(x: 100, y: 100, width: 80, height: 80)

        #expect(source.morphInterpolated(to: target, progress: -1) == source)
        #expect(source.morphInterpolated(to: target, progress: 2) == target)
        #expect(source.morphInterpolated(to: target, progress: .nan) == source)
    }

    @Test func validatesUsableMorphFrames() {
        #expect(CGRect(x: 0, y: 0, width: 40, height: 40).isUsableForMorph)
        #expect(!CGRect(x: 0, y: 0, width: 1, height: 40).isUsableForMorph)
        #expect(!CGRect(x: CGFloat.infinity, y: 0, width: 40, height: 40).isUsableForMorph)
    }
}
