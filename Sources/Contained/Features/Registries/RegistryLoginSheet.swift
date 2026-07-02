import SwiftUI
import ContainedDesignSystem
import ContainedCore

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
            SheetHeader(title: "Registry login", onCancel: { dismiss() }) {
                if busy {
                    ProgressView().controlSize(.small).frame(width: Tokens.IconSize.control, height: Tokens.IconSize.control)
                } else {
                    GlassButton(singleItem: true) {
                        GlassButtonItem(systemName: "checkmark", help: "Log in") { submit() }
                            .disabled(server.trimmingCharacters(in: .whitespaces).isEmpty
                                      || username.trimmingCharacters(in: .whitespaces).isEmpty
                                      || password.isEmpty)
                    }
                }
            }
            VStack(spacing: Tokens.Space.l) {
                PanelSection(header: "Credentials") {
                    PanelField(label: "Server") {
                        TextField("", text: $server, prompt: Text("e.g. ghcr.io, docker.io"))
                            .textContentType(.URL)
                            .textFieldStyle(.roundedBorder)
                    }
                    PanelField(label: "Username") {
                        TextField("", text: $username, prompt: Text("registry username"))
                            .textContentType(.username)
                            .textFieldStyle(.roundedBorder)
                    }
                    PanelField(label: "Password") {
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
            .padding(Tokens.Space.l)
        }
        .frame(Tokens.SheetSize.small)
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
            } catch let e as CommandError { error = e.userMessage; busy = false }
            catch { self.error = error.localizedDescription; busy = false }
        }
    }
}
