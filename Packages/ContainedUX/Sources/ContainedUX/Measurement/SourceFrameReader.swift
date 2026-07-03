import SwiftUI
import ContainedUI

public extension UX.Measurement {
struct SourceFrameReader<ID: Hashable>: View {
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
                key: UX.Measurement.SourceFramesKey<ID>.self,
                value: Dictionary(uniqueKeysWithValues: ids.map { ($0, frame) })
            )
        }
    }
}

struct SourceFramesKey<ID: Hashable>: PreferenceKey {
    public static var defaultValue: [ID: CGRect] { [:] }

    public static func reduce(value: inout [ID: CGRect],
                              nextValue: () -> [ID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
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
        UX.Morph.Geometry.isUsableFrame(self)
    }

    func isClose(to other: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(minX - other.minX) <= tolerance &&
        abs(minY - other.minY) <= tolerance &&
        abs(width - other.width) <= tolerance &&
        abs(height - other.height) <= tolerance
    }
}

#Preview("Source Frame Reader") {
    SourceFrameReaderPreview()
        .frame(width: 360, height: 220)
}

private struct SourceFrameReaderPreview: View {
    @State private var frames: [String: CGRect] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
            UI.Action.Group(UI.Action.Item(systemName: "plus", help: "Measured") {})
                .background(UX.Measurement.SourceFrameReader("button", coordinateSpaceName: "preview-space"))
            Text(frameSummary)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(UI.Layout.Spacing.xl)
        .coordinateSpace(name: "preview-space")
        .onPreferenceChange(UX.Measurement.SourceFramesKey<String>.self) { frames = $0 }
    }

    private var frameSummary: String {
        guard let frame = frames["button"] else { return "measuring..." }
        return "x:\(Int(frame.minX)) y:\(Int(frame.minY)) w:\(Int(frame.width)) h:\(Int(frame.height))"
    }
}
