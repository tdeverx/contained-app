import SwiftUI
import ContainedDesignSystem
import ContainedCore
import ContainedRuntime

/// Sign in to a registry. The user types their own credentials; the password is sent via stdin.
/// Registry credential management lives in Settings → Registries; this sheet is launched from that tab.
struct RegistryLoginSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: AppText.string("registry.login.title", defaultValue: "Registry login"),
                        cancelHelp: AppText.close,
                        onCancel: { dismiss() }) {
                if busy {
                    ProgressView().controlSize(.small).frame(width: DesignTokens.IconSize.control, height: DesignTokens.IconSize.control)
                } else {
                    DesignActionGroup(DesignAction(systemName: "checkmark",
                                                   help: AppText.logIn,
                                                   isEnabled: !server.trimmingCharacters(in: .whitespaces).isEmpty
                                                       && !username.trimmingCharacters(in: .whitespaces).isEmpty
                                                       && !password.isEmpty) {
                        submit()
                    })
                }
            }
            VStack(spacing: DesignTokens.Space.l) {
                PanelSection(header: AppText.string("registry.credentials", defaultValue: "Credentials")) {
                    PanelField(label: AppText.string("registry.server", defaultValue: "Server")) {
                        TextField("", text: $server, prompt: Text("e.g. ghcr.io, docker.io"))
                            .textContentType(.URL)
                            .textFieldStyle(.roundedBorder)
                    }
                    PanelField(label: AppText.string("registry.username", defaultValue: "Username")) {
                        TextField("", text: $username, prompt: Text("registry username"))
                            .textContentType(.username)
                            .textFieldStyle(.roundedBorder)
                    }
                    PanelField(label: AppText.string("registry.password", defaultValue: "Password")) {
                        SecureField("", text: $password, prompt: Text("password or access token"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                if let error {
                    PanelSection {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(DesignTokens.Space.l)
        }
        .frame(DesignTokens.SheetSize.small)
        .sheetMaterial()
    }

    private func submit() {
        guard let client = app.client else { return }
        busy = true; error = nil
        Task {
            do {
                _ = try await client.registryLogin(server: server.trimmingCharacters(in: .whitespaces),
                                                   username: username.trimmingCharacters(in: .whitespaces),
                                                   password: password)
                await app.refreshRegistries()
                dismiss()
            } catch let e as CommandError { error = e.appDisplayMessage; busy = false }
            catch { self.error = error.appDisplayMessage; busy = false }
        }
    }
}
