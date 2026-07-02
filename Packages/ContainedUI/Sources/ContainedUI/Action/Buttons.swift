import SwiftUI

/// Package-owned progress capsule for action slots that are temporarily busy.
public struct ActionProgressCapsule: View {
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
public enum ActionTextProminence {
    case standard
    case prominent
}

/// Package-owned text action button for command rows and form footers.
public struct ActionTextButton: View {
    public var title: String
    public var systemName: String
    public var help: String
    public var role: ButtonRole?
    public var prominence: ActionTextProminence
    public var controlSize: ControlSize
    public var isEnabled: Bool
    public var action: () -> Void

    public init(title: String,
                systemName: String,
                help: String? = nil,
                role: ButtonRole? = nil,
                prominence: ActionTextProminence = .standard,
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
public struct ActionToggleButton: View {
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
