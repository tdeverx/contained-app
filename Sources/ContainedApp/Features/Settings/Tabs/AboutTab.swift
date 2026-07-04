import SwiftUI
import ContainedUI
import ContainedCore

// MARK: - About

struct AboutTab: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        SettingsForm {
            Section {
                HStack(spacing: UI.Layout.Spacing.m) {
                    Image(systemName: "shippingbox.fill")
                        .resizable()
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: UI.Control.Size.appIcon, height: UI.Control.Size.appIcon)
                    VStack(alignment: .leading, spacing: UI.Layout.Spacing.xxs) {
                        Text("Contained").designTitleLabelStyle()
                        Text("Version \(appVersion)").designSecondaryCallout()
                        Text("A native macOS UI for Apple’s container runtime.")
                            .designSecondaryCaption()
                    }
                    Spacer()
                }
            }

            Section(AppText.sectionSettingsRuntime) {
                ForEach(app.availableRuntimeDescriptors, id: \.kind) { descriptor in
                    UI.Form.Row(title: descriptor.displayName) {
                        Text(app.runtimeVersion(for: descriptor.kind) ?? "—").designSecondaryValueStyle()
                    }
                }
                UI.Form.Row(title: AppText.string("settings.about.apiServer", defaultValue: "API server")) { Text(app.systemStatus?.apiServerVersion ?? "—").designSecondaryValueStyle() }
            }

            Section {
                UI.Form.Row(title: AppText.string("settings.about.copyright", defaultValue: "Copyright")) { Text("© 2026 Contained").designSecondaryValueStyle() }
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
