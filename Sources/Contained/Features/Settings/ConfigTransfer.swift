import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ContainedDesignSystem

enum ConfigImportMode: String, CaseIterable, Identifiable {
    case merge = "Merge"
    case replace = "Replace"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .merge: return AppText.string("backup.importMode.merge", defaultValue: "Merge")
        case .replace: return AppText.string("backup.importMode.replace", defaultValue: "Replace")
        }
    }
    var replacesExistingData: Bool { self == .replace }
}

extension UTType {
    static let containedBackup = UTType(exportedAs: "app.contained.backup")
}

struct ConfigTransferControls: View {
    @Environment(AppModel.self) private var app
    @State private var sections = Set(AppStateSection.allCases)
    @State private var importMode: ConfigImportMode = .merge

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
            ForEach(AppStateSection.allCases) { section in
                Toggle(section.displayName, isOn: binding(for: section))
                    .toggleStyle(.checkbox)
            }
            Picker("Import mode", selection: $importMode) {
                ForEach(ConfigImportMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Export Backup…") { exportBackup() }
                Button("Import Backup…") { importBackup() }
                Button("Clean Up Orphans") { app.purgeDeadRows() }
            }
        }
    }

    private func binding(for section: AppStateSection) -> Binding<Bool> {
        Binding {
            sections.contains(section)
        } set: { isOn in
            if isOn { sections.insert(section) }
            else { sections.remove(section) }
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.containedBackup, .json]
        panel.nameFieldStringValue = "Contained Backup.containedbackup"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try app.exportConfiguration(to: url, sections: sections)
            app.flash("Exported backup")
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.containedBackup, .json]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try app.importConfiguration(from: url,
                                        sections: sections,
                                        replace: importMode.replacesExistingData)
            app.flash("Imported backup")
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }
}
