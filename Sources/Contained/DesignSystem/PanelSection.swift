import SwiftUI

/// A grouped settings-style section for hugging panels — the intrinsic-height replacement for a Form
/// `Section`. Renders an optional header label, a flat glass card holding its rows, and an optional
/// caption footer, matching the app's glass-card language instead of Form's solid grouped backing.
///
/// Supports two header affordances: `collapsible` (a chevron that folds the card away) and an `enabled`
/// binding (a switch in the header that disables/hides the body — used for opt-in sections like the
/// per-card customization blocks).
struct PanelSection<Content: View>: View {
    var header: String? = nil
    var footer: String? = nil
    var rowSpacing: CGFloat = Tokens.Space.m
    var collapsible: Bool = false
    /// Subtle blue treatment for sections containing explicit non-default values.
    var highlighted: Bool = false
    /// When provided, the header shows a switch; turning it off hides the body (and footer).
    var enabled: Binding<Bool>? = nil
    @ViewBuilder var content: () -> Content

    @State private var collapsed = false

    private var bodyHidden: Bool {
        if let enabled, !enabled.wrappedValue { return true }
        return collapsible && collapsed
    }

    private var hasHeader: Bool { header != nil || collapsible || enabled != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if hasHeader { headerRow }
            if !bodyHidden {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    content()
                }
                .padding(Tokens.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: false)
                .overlay {
                    if highlighted {
                        RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.38), lineWidth: 1)
                    }
                }
                if let footer {
                    // Markdown-aware so footers can use **bold** / `code`, like the old Form footers.
                    Text(.init(footer)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, Tokens.Space.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: Tokens.Space.s) {
            if collapsible {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
            }
            if let header {
                HStack(spacing: Tokens.Space.xs) {
                    if highlighted {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                    Text(header)
                        .font(.headline)
                        .foregroundStyle(highlighted ? Color.accentColor : Color.primary)
                }
            }
            Spacer(minLength: Tokens.Space.s)
            if let enabled {
                Toggle("", isOn: enabled).labelsHidden().toggleStyle(.switch)
            }
        }
        .padding(.leading, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            guard collapsible else { return }
            withAnimation(.easeOut(duration: 0.18)) { collapsed.toggle() }
        }
    }
}

/// A single settings row: a leading title (+ optional subtitle), a trailing control, and an optional
/// info popover that reveals on hover at the far-right edge. Set `error` to tint the title red and show
/// a red caption beneath — the scaffold's "something is wrong with this item" signal.
struct PanelRow<Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    var info: String? = nil
    var error: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Tokens.Space.m) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).foregroundStyle(error == nil ? Color.primary : Color.red)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Tokens.Space.m)
                trailing()
                HoverInfo(info: info, hovering: hovering)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension PanelRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, info: String? = nil, error: String? = nil) {
        self.init(title: title, subtitle: subtitle, info: info, error: error) { EmptyView() }
    }
}

/// A switch row — the common Toggle case, rendered label-left / switch-right like a grouped Form.
struct PanelToggleRow: View {
    var title: String
    var subtitle: String? = nil
    var info: String? = nil
    var error: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        PanelRow(title: title, subtitle: subtitle, info: info, error: error) {
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}

/// A labeled form field: a leading label, an expanding control (text field, picker, slider…), and an
/// optional hover-revealed info popover. The form-row counterpart to `PanelRow` (which hugs its trailing
/// control); here the control fills the remaining width like a grouped Form field. `error` tints the
/// label red and shows a red caption beneath.
struct PanelField<Control: View>: View {
    var label: String
    var info: String? = nil
    var error: String? = nil
    var labelWidth: CGFloat = 124
    @ViewBuilder var control: () -> Control

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Tokens.Space.m) {
                Text(label)
                    .frame(width: labelWidth, alignment: .leading)
                    .foregroundStyle(error == nil ? Color.primary : Color.red)
                control().frame(maxWidth: .infinity)
                HoverInfo(info: info, hovering: hovering)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
                    .padding(.leading, labelWidth + Tokens.Space.m)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// A trailing info affordance that only appears while its row is hovered. Wraps `InfoButton`, so it
/// still honors the global "Show info tips" setting and the tap-to-pin popover.
private struct HoverInfo: View {
    var info: String?
    var hovering: Bool

    var body: some View {
        if let info {
            InfoButton(info)
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
        }
    }
}
