import SwiftUI
import AppKit
import ContainedCore

// MARK: - About

struct AboutTab: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection {
                HStack(spacing: Tokens.Space.m) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contained").font(.title3.weight(.semibold))
                        Text("Version \(appVersion)").font(.callout).foregroundStyle(.secondary)
                        Text("A native macOS UI for Apple’s container runtime.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            PanelSection(header: "Runtime") {
                PanelRow(title: "Container CLI") { Text(app.cliVersion ?? "—").foregroundStyle(.secondary) }
                PanelRow(title: "API server") { Text(app.systemStatus?.apiServerVersion ?? "—").foregroundStyle(.secondary) }
            }

            PanelSection {
                PanelRow(title: "Copyright") { Text("© 2026 Contained").foregroundStyle(.secondary) }
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
