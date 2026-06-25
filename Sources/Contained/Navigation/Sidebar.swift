import SwiftUI
import ContainedCore

/// Native `.sidebar` list grouped Workloads / Infra / System with live count badges.
struct Sidebar: View {
    @Environment(AppModel.self) private var app
    @Binding var selection: AppSection

    var body: some View {
        List(selection: $selection) {
            ForEach(AppSection.Group.allCases) { group in
                Section(group.rawValue) {
                    ForEach(group.sections) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .badge(badge(for: section))
                            .tag(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
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
