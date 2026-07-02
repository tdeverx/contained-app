import Foundation

public extension Core.Compose {
    static func parse(_ yaml: String, projectName: String) throws -> Project {
        try ComposeParser.parse(yaml, projectName: projectName)
    }
}
