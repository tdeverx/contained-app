import SwiftUI
import ContainedCore

/// Native `.sidebar` list grouped Workloads / Infra / System with live count badges.
struct Sidebar: View {
    @Environment(AppModel.self) private var app
    @Binding var selection: AppSection

    var body: some View {
        // No `selection:` binding: the native sidebar highlight is drawn by AppKit in the *system*
        // accent and can't be recolored from SwiftUI. We suppress it and render selection ourselves
        // (a tinted capsule via `.listRowBackground`) so the in-app Accent tint drives it. Keyboard
        // section-switching stays available via the ⌘1–9 "Go" menu shortcuts.
        List {
            ForEach(AppSection.Group.allCases) { group in
                Section(group.rawValue) {
                    ForEach(group.sections) { section in
                        row(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func row(_ section: AppSection) -> some View {
        let isSelected = selection == section
        Label(section.title, systemImage: section.systemImage)
            .badge(badge(for: section))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .listRowBackground(selectionBackground(isSelected))
            .onTapGesture { selection = section }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The selected row's highlight: a prominent, accent-tinted Liquid Glass capsule, inset from the
    /// row edges so it floats like a native sidebar selection.
    @ViewBuilder
    private func selectionBackground(_ isSelected: Bool) -> some View {
        if isSelected {
            let shape = RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
            Color.clear
                .glassEffect(.regular.tint(app.settings.accentTint.color).interactive(), in: shape)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
        } else {
            Color.clear
        }
    }

    /// A count badge, or `nil` to show none (keeps the sidebar clean and consistent).
    private func badge(for section: AppSection) -> Text? {
        let count: Int
        switch section {
        case .containers: count = app.containers.snapshots.count
        case .images: count = app.diskUsage?.images.total ?? 0
        default: count = 0
        }
        return count > 0 ? Text("\(count)") : nil
    }
}
