import SwiftUI

/// Package-owned progress capsule for action slots that are temporarily busy.
public extension UI.Action {
struct ProgressCapsule: View {
    public var controlSize: ControlSize

    public init(controlSize: ControlSize = .small) {
        self.controlSize = controlSize
    }

    public var body: some View {
        MaterialButton(singleItem: true) {
            ProgressView()
                .controlSize(controlSize)
                .frame(width: UI.Tokens.Toolbar.buttonItemHeight,
                       height: UI.Tokens.Toolbar.buttonItemHeight)
        }
    }
}

/// Prominence levels for package-owned text action buttons.
enum TextProminence {
    case standard
    case prominent
}

/// Package-owned text action button for command rows and form footers.
struct TextButton: View {
    public var title: String
    public var systemName: String
    public var help: String
    public var role: ButtonRole?
    public var prominence: UI.Action.TextProminence
    public var controlSize: ControlSize
    public var isEnabled: Bool
    public var action: () -> Void

    public init(title: String,
                systemName: String,
                help: String? = nil,
                role: ButtonRole? = nil,
                prominence: UI.Action.TextProminence = .standard,
                controlSize: ControlSize = .regular,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = title
        self.systemName = systemName
        self.help = help ?? title
        self.role = role
        self.prominence = prominence
        self.controlSize = controlSize
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        switch prominence {
        case .standard:
            Button(role: role, action: action) {
                Label(title, systemImage: systemName)
            }
            .buttonStyle(.glass)
            .controlSize(controlSize)
            .help(help)
            .disabled(!isEnabled)
        case .prominent:
            Button(role: role, action: action) {
                Label(title, systemImage: systemName)
            }
            .buttonStyle(.glassProminent)
            .controlSize(controlSize)
            .help(help)
            .disabled(!isEnabled)
        }
    }
}

/// Package-owned toggle button used when a binary command belongs in toolbar or panel chrome.
struct ToggleButton: View {
    @Binding public var isOn: Bool
    public var title: String
    public var systemName: String

    public init(isOn: Binding<Bool>,
                title: String,
                systemName: String) {
        self._isOn = isOn
        self.title = title
        self.systemName = systemName
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: systemName)
        }
        .toggleStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
}
}

#Preview("Action Buttons") {
    VStack(alignment: .leading, spacing: UI.Tokens.Space.l) {
        UI.Action.TextButton(title: "Save",
                             systemName: "checkmark",
                             prominence: .prominent) {}
        UI.Action.TextButton(title: "Remove",
                             systemName: "trash",
                             role: .destructive) {}
        UI.Action.ToggleButton(isOn: .constant(true),
                               title: "Pinned",
                               systemName: "pin.fill")
        UI.Action.ProgressCapsule()
    }
    .padding(UI.Tokens.Space.xl)
}
