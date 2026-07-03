public extension UX.Panel {
struct BackdropStyle: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let dim = BackdropStyle(rawValue: 1 << 0)
    public static let blur = BackdropStyle(rawValue: 1 << 1)
    public static let blurAndDim: BackdropStyle = [.blur, .dim]
}
}
