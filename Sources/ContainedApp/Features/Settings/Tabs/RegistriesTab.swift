import SwiftUI
import ContainedUI
import ContainedCore

// MARK: - Registries

/// Registry logins live here: list signed-in registries and log in / out.
struct RegistriesTab: View {
    @Environment(AppModel.self) private var app
    @State private var loggingIn = false
    @State private var loginHost = ""
    @State private var loginRuntime = AppRuntimeIntent.placeholderKind
    @State private var loggingOut: Core.Registry.Login?

    var body: some View {
        SettingsForm {
            if !app.registryUpdateFailures.isEmpty {
                Section("Image update checks") {
                    ForEach(app.registryUpdateFailures) { failure in
                        VStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                            Text(app.registryFailureMessage(host: failure.host, kind: failure.kind))
                            Text("\(failure.references.count) affected tags · Retry after \(failure.retryAfter.formatted())")
                                .foregroundStyle(.secondary)
                            Button("Retry Now") { Task { await app.retryRegistryUpdates(failure) } }
                            Button("Refresh Login…") {
                                loginHost = failure.host
                                loginRuntime = failure.runtimeKind
                                loggingIn = true
                            }
                        }
                    }
                }
            }
            Section {
                if app.registries.isEmpty {
                    Text("Not signed in to any registries.")
                        .designSecondaryValueStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(app.registries) { login in
                        UI.List.MetadataRow(systemImage: "key",
                                          title: login.host,
                                          subtitle: registrySubtitle(login)) {
                            Button("Log Out", role: .destructive) { loggingOut = login }
                        }
                        .contextMenu {
                            UI.Copy.ValueLabel("Copy Server", value: login.host)
                            Divider()
                            Button(role: .destructive) { loggingOut = login } label: { Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right") }
                        }
                    }
                }
            } header: {
                Text(AppText.string("settings.registries.signedIn", defaultValue: "Signed-in registries"))
            } footer: {
                Text(AppText.string("settings.registries.footer", defaultValue: "Credentials are typed by you and piped to the CLI via stdin, so the password never lands in the process list. Contained doesn't store it."))
            }

            Section {
                Button("Log In to Registry…") {
                    loginHost = ""
                    loginRuntime = AppRuntimeIntent.placeholderKind
                    loggingIn = true
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task { await app.refreshRegistries() }
        .sheet(isPresented: $loggingIn) { RegistryLoginSheet(server: loginHost, runtimeKind: loginRuntime) }
        .confirmationDialog("Log out of \(loggingOut?.host ?? "")?",
                            isPresented: logoutBinding, presenting: loggingOut) { login in
            Button("Log out", role: .destructive) { Task { await logout(login) } }
        } message: { _ in Text("Removes the stored credentials for this registry.") }
    }

    private var logoutBinding: Binding<Bool> {
        Binding(get: { loggingOut != nil }, set: { if !$0 { loggingOut = nil } })
    }

    private func logout(_ login: Core.Registry.Login) async {
        guard let client = app.client else { return }
        do {
            _ = try await client.registryLogout(server: login.host, runtimeKind: login.runtimeKind)
            app.registryCredentialsChanged(host: login.host, runtimeKind: login.runtimeKind)
            await app.refreshRegistries()
        }
        catch let error as Core.Command.Error { app.flash(error.appDisplayMessage) }
        catch { app.flash(error.appDisplayMessage) }
    }

    private func registrySubtitle(_ login: Core.Registry.Login) -> String {
        let runtime = app.runtimeDescriptor(for: login.runtimeKind)?.displayName ?? login.runtimeKind.rawValue
        if let username = login.username {
            return AppText.string("settings.registries.usernameRuntime",
                                  defaultValue: "\(runtime), as \(username)")
        }
        return runtime
    }
}
