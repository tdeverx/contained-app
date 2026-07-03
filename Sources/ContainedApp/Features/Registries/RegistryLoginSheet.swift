import SwiftUI
import ContainedUI
import ContainedCore

/// Sign in to a registry. The user types their own credentials; the password is sent via stdin.
/// Registry credential management lives in Settings → Registries; this sheet is launched from that tab.
struct RegistryLoginSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var runtimeKind = Core.Runtime.Kind.appleContainer
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            UI.Panel.SheetTitleBar(title: AppText.string("registry.login.title", defaultValue: "Registry login"),
                        cancelHelp: AppText.close,
                        onCancel: { dismiss() }) {
                if busy {
                    UI.State.ProgressIndicator(frameSize: UI.Control.Size.control)
                } else {
                    UI.Action.Group(UI.Action.Item(systemName: "checkmark",
                                                   help: AppText.logIn,
                                                   isEnabled: !server.trimmingCharacters(in: .whitespaces).isEmpty
                                                       && !username.trimmingCharacters(in: .whitespaces).isEmpty
                                                       && !password.isEmpty) {
                        submit()
                    })
                }
            }
            VStack(spacing: UI.Layout.Spacing.l) {
                UI.Panel.Section(header: AppText.runtime) {
                    Picker("", selection: $runtimeKind) {
                        ForEach(registryRuntimes, id: \.kind) { descriptor in
                            Text(descriptor.displayName).tag(descriptor.kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(registryRuntimes.count < 2)
                }
                UI.Panel.Section(header: AppText.string("registry.credentials", defaultValue: "Credentials")) {
                    UI.Panel.Field(label: AppText.string("registry.server", defaultValue: "Server")) {
                        TextField("", text: $server, prompt: Text("e.g. ghcr.io, docker.io"))
                            .textContentType(.URL)
                            .textFieldStyle(.roundedBorder)
                    }
                    UI.Panel.Field(label: AppText.string("registry.username", defaultValue: "Username")) {
                        TextField("", text: $username, prompt: Text("registry username"))
                            .textContentType(.username)
                            .textFieldStyle(.roundedBorder)
                    }
                    UI.Panel.Field(label: AppText.string("registry.password", defaultValue: "Password")) {
                        SecureField("", text: $password, prompt: Text("password or access token"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                if let error {
                    UI.Panel.Section {
                        UI.State.InlineStatus(error,
                                           systemImage: "exclamationmark.triangle",
                                           tone: .error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(UI.Layout.Spacing.l)
        }
        .frame(UI.Panel.SheetSize.small)
        .sheetMaterial()
        .onAppear(perform: normalizeRuntimeSelection)
    }

    private var registryRuntimes: [Core.Runtime.Descriptor] {
        let runtimes = app.availableRuntimeDescriptors.filter { $0.supports(.registries) }
        return runtimes.isEmpty ? app.availableRuntimeDescriptors : runtimes
    }

    private func normalizeRuntimeSelection() {
        guard let first = registryRuntimes.first, !registryRuntimes.contains(where: { $0.kind == runtimeKind }) else { return }
        runtimeKind = first.kind
    }

    private func submit() {
        guard let client = app.client else { return }
        busy = true; error = nil
        Task {
            do {
                _ = try await client.registryLogin(server: server.trimmingCharacters(in: .whitespaces),
                                                   username: username.trimmingCharacters(in: .whitespaces),
                                                   password: password,
                                                   runtimeKind: runtimeKind)
                await app.refreshRegistries()
                dismiss()
            } catch let e as Core.Command.Error { error = e.appDisplayMessage; busy = false }
            catch { self.error = error.appDisplayMessage; busy = false }
        }
    }
}
