import Foundation

public extension Core.Compose {
    static func parse(_ yaml: String, projectName: String) throws -> Project {
        try Core.Compose.Parser.parse(yaml, projectName: projectName)
    }
}
