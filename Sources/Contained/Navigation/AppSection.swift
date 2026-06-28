import SwiftUI

/// The app's content destinations. The sidebar is gone — everything lives in the toolbar + creation
/// flow now: images/templates/activity/system in toolbar panels, build/volumes/networks in the `+`
/// flow, registry credentials in Settings. Only Containers remains a standing page, so this is a
/// single case kept for the refresh coordinator and the command palette's "Go to" entry.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case containers

    var id: String { rawValue }
    var title: String { "Containers" }
    var systemImage: String { "shippingbox" }
}
