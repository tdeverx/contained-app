import SwiftUI

public struct MorphSourceFrameReader<ID: Hashable>: View {
    public var ids: [ID]
    public var coordinateSpaceName: String

    public init(_ id: ID, coordinateSpaceName: String) {
        self.ids = [id]
        self.coordinateSpaceName = coordinateSpaceName
    }

    public init(_ ids: [ID], coordinateSpaceName: String) {
        self.ids = ids
        self.coordinateSpaceName = coordinateSpaceName
    }

    public var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(coordinateSpaceName))
            Color.clear.preference(
                key: MorphSourceFramesKey<ID>.self,
                value: Dictionary(uniqueKeysWithValues: ids.map { ($0, frame) })
            )
        }
    }
}

public struct MorphSourceFramesKey<ID: Hashable>: PreferenceKey {
    public static var defaultValue: [ID: CGRect] { [:] }

    public static func reduce(value: inout [ID: CGRect],
                              nextValue: () -> [ID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

public extension Dictionary where Value == CGRect {
    func isClose(to other: [Key: CGRect], tolerance: CGFloat = 0.5) -> Bool {
        guard count == other.count else { return false }
        return allSatisfy { key, frame in
            guard let otherFrame = other[key] else { return false }
            return frame.isClose(to: otherFrame, tolerance: tolerance)
        }
    }
}

public extension CGRect {
    var isUsableForMorph: Bool {
        MorphGeometry.isUsableFrame(self)
    }

    func isClose(to other: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(minX - other.minX) <= tolerance &&
        abs(minY - other.minY) <= tolerance &&
        abs(width - other.width) <= tolerance &&
        abs(height - other.height) <= tolerance
    }
}
