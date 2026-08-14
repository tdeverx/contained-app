import SwiftUI

public extension UI.Form {
enum LabelState: Equatable {
    case normal
    case changed
    case invalid

    var foregroundStyle: Color {
        switch self {
        case .normal: .primary
        case .changed: .accentColor
        case .invalid: .red
        }
    }
}

struct Row<Trailing: View>: View {
    public var title: String
    public var subtitle: String?
    public var info: String?
    public var error: String?
    public var isChanged: Bool
    @ViewBuilder public var trailing: () -> Trailing

    @State private var labelHovering = false

    public init(title: String,
                subtitle: String? = nil,
                info: String? = nil,
                error: String? = nil,
                isChanged: Bool = false,
                @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.info = info
        self.error = error
        self.isChanged = isChanged
        self.trailing = trailing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: UI.Tokens.Space.xxs) {
            SharedAdaptiveLabeledRow {
                labelStack
            } trailing: {
                trailing()
            }
            .contentShape(Rectangle())
            .onHover { labelHovering = $0 }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: UI.Tokens.Space.xxs) {
            label
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var label: some View {
        HStack(spacing: UI.Tokens.Space.xs) {
            Text(title)
                .foregroundStyle(labelState.foregroundStyle)
            if let info {
                UI.Control.InfoButton(info, visible: labelHovering)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var labelState: UI.Form.LabelState {
        if error != nil { return .invalid }
        if isChanged { return .changed }
        return .normal
    }
}
}

public extension UI.Form.Row where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, info: String? = nil, error: String? = nil, isChanged: Bool = false) {
        self.init(title: title, subtitle: subtitle, info: info, error: error, isChanged: isChanged) { EmptyView() }
    }
}

public extension UI.Form {
struct ToggleRow: View {
    public var title: String
    public var subtitle: String?
    public var info: String?
    public var error: String?
    public var isChanged: Bool
    @Binding public var isOn: Bool

    public init(title: String,
                subtitle: String? = nil,
                info: String? = nil,
                error: String? = nil,
                isChanged: Bool = false,
                isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.info = info
        self.error = error
        self.isChanged = isChanged
        self._isOn = isOn
    }

    public var body: some View {
        UI.Form.Row(title: title, subtitle: subtitle, info: info, error: error, isChanged: isChanged) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

struct Field<Control: View>: View {
    public var label: String
    public var info: String?
    public var error: String?
    public var isChanged: Bool
    public var labelWidth: CGFloat
    @ViewBuilder public var control: () -> Control

    @State private var labelHovering = false

    public init(label: String,
                info: String? = nil,
                error: String? = nil,
                isChanged: Bool = false,
                labelWidth: CGFloat = 124,
                @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.info = info
        self.error = error
        self.isChanged = isChanged
        self.labelWidth = labelWidth
        self.control = control
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: UI.Tokens.Space.xxs) {
            HStack(spacing: UI.Tokens.Space.m) {
                fieldLabel
                    .frame(width: labelWidth, alignment: .leading)
                control()
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .onHover { labelHovering = $0 }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, labelWidth + UI.Tokens.Space.m)
            }
        }
    }

    private var fieldLabel: some View {
        HStack(spacing: UI.Tokens.Space.xs) {
            Text(label)
                .foregroundStyle(labelState.foregroundStyle)
            if let info {
                UI.Control.InfoButton(info, visible: labelHovering)
            }
        }
    }

    private var labelState: UI.Form.LabelState {
        if error != nil { return .invalid }
        if isChanged { return .changed }
        return .normal
    }
}
}

#Preview("Form Rows") {
    @Previewable @State var enabled = true
    @Previewable @State var name = "nginx"

    UI.Form.Grouped {
        Section("Essentials") {
            UI.Form.Field(label: "Image", info: "Container image reference.") {
                TextField("nginx:latest", text: $name)
            }
            UI.Form.ToggleRow(title: "Run in background",
                              info: "Maps to detached runtime execution.",
                              isChanged: true,
                              isOn: $enabled)
            UI.Form.Row(title: "Status", subtitle: "Ready to run") {
                Text("Ready")
                    .foregroundStyle(.secondary)
            }
        }
    }
    .frame(width: 420, height: 260)
}
