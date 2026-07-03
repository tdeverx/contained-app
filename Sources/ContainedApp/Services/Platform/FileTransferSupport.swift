import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let containedBackup = UTType(exportedAs: "app.contained.backup")
    static let tarArchive = UTType(filenameExtension: "tar") ?? .data
    static let yamlDocument = UTType(filenameExtension: "yaml") ?? .data
    static let ymlDocument = UTType(filenameExtension: "yml") ?? .yamlDocument

    static let composeDocuments: [UTType] = [.yamlDocument, .ymlDocument]
    static let imageArchives: [UTType] = [.tarArchive]
    static let containedBackupDocuments: [UTType] = [.containedBackup, .json]
}

struct DataFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json, .containedBackup, .tarArchive] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum StagedFile {
    static func url(named fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Contained", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    static func cleanup(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
