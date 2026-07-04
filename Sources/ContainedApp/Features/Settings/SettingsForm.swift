import SwiftUI
import ContainedUI

struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        UI.Form.Grouped {
            content()
        }
    }
}
