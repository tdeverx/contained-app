import SwiftUI

public extension UI.Copy {
    /// SwiftUI-native copy affordance for values that used to need imperative pasteboard writes.
    struct ValueLabel: View {
        public var title: String
        public var value: String
        public var systemName: String
        public var help: String

        public init(_ title: String,
                    value: String,
                    systemName: String = "doc.on.doc",
                    help: String? = nil) {
            self.title = title
            self.value = value
            self.systemName = systemName
            self.help = help ?? title
        }

        public var body: some View {
            Label(title, systemImage: systemName)
                .copyable([value])
                .help(help)
        }
    }

    struct Icon: View {
        public var value: String
        public var systemName: String
        public var help: String

        public init(value: String,
                    systemName: String = "doc.on.doc",
                    help: String) {
            self.value = value
            self.systemName = systemName
            self.help = help
        }

        public var body: some View {
            Image(systemName: systemName)
                .foregroundStyle(.secondary)
                .copyable([value])
                .help(help)
                .accessibilityLabel(help)
        }
    }
}
