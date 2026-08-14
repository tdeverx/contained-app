import Foundation

/// A session-local collection used to focus the main container grid.
struct ContainerGroup: Identifiable, Hashable {
    let id: UUID
    var name: String
    var containerIDs: Set<String>

    init(id: UUID = UUID(), name: String, containerIDs: Set<String> = []) {
        self.id = id
        self.name = name
        self.containerIDs = containerIDs
    }
}
