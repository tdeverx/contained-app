import SwiftUI

/// Semantic action description for package-owned glass action chrome.
public struct ActionItem {
    public var systemName: String
    public var title: String?
    public var help: String
    public var role: ButtonRole?
    public var tint: Color?
    public var isCancel: Bool
    public var isEnabled: Bool
    public var action: () -> Void

    public init(systemName: String,
                title: String? = nil,
                help: String? = nil,
                role: ButtonRole? = nil,
                tint: Color? = nil,
                isCancel: Bool = false,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.systemName = systemName
        self.title = title
        self.help = help ?? title ?? ""
        self.role = role
        self.tint = tint
        self.isCancel = isCancel
        self.isEnabled = isEnabled
        self.action = action
    }
}
