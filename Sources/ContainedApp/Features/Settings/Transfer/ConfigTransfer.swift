import SwiftUI
import UniformTypeIdentifiers
import ContainedUI

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

struct ConfigTransferControls: View {
    @Environment(AppModel.self) private var app
    @State private var sections = Set(AppStateSection.allCases)
    @State private var importMode: ConfigImportMode = .merge
    @State private var exportingBackup = false
    @State private var importingBackup = false
    @State private var backupDocument: DataFileDocument?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
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
        .fileExporter(isPresented: $exportingBackup,
                      document: backupDocument,
                      contentTypes: UTType.containedBackupDocuments,
                      defaultFilename: "Contained Backup.containedbackup") { result in
            backupDocument = nil
            switch result {
            case .success:
                app.flash(AppText.exportedBackup)
            case .failure(let error):
                app.flash(error.appDisplayMessage)
            }
        }
        .fileImporter(isPresented: $importingBackup,
                      allowedContentTypes: UTType.containedBackupDocuments) { result in
            handleBackupImport(result)
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
        do {
            backupDocument = DataFileDocument(data: try app.configurationData(sections: sections))
            exportingBackup = true
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }

    private func importBackup() {
        importingBackup = true
    }

    private func handleBackupImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            if case .failure(let error) = result { app.flash(error.appDisplayMessage) }
            return
        }
        do {
            try app.importConfiguration(from: url,
                                        sections: sections,
                                        replace: importMode.replacesExistingData)
            app.flash(AppText.importedBackup)
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }
}
