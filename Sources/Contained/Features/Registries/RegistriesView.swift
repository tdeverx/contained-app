import SwiftUI
import ContainedCore

/// Registry logins: list, log in, log out. Credentials are entered by the user and piped to the
/// CLI via `--password-stdin`, so the password never lands in argv or the process list.
struct RegistriesView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var loggingIn = false
    @State private var loggingOut: RegistryLogin?

    var body: some View {
        ResourceScaffold(isEmpty: app.registries.isEmpty, emptyTitle: "No registry logins",
                         emptySymbol: "key",
                         emptyMessage: "Log in to a registry to pull private images and push your builds.") {
            ForEach(app.registries) { login in row(login) }
        }
        .task { await app.refreshResource(.registries) }
        .onAppear { if ui.pendingAction == .registryLogin { ui.pendingAction = nil; loggingIn = true } }
        .onChange(of: ui.pendingAction) { _, _ in if ui.pendingAction == .registryLogin { ui.pendingAction = nil; loggingIn = true } }
        .sheet(isPresented: $loggingIn) { RegistryLoginSheet() }
        .confirmationDialog("Log out of \(loggingOut?.host ?? "")?",
                            isPresented: logoutBinding, presenting: loggingOut) { login in
            Button("Log out", role: .destructive) { Task { await logout(login) } }
        } message: { _ in Text("Removes the stored credentials for this registry.") }
    }

    private func row(_ login: RegistryLogin) -> some View {
        ResourceRow(symbol: "key.fill", tint: .accentColor, title: login.host,
                    subtitle: login.username.map { "as \($0)" } ?? "") {
            GlassRowMenu { menuItems(login) }
        }
        .contextMenu { menuItems(login) }
    }

    @ViewBuilder
    private func menuItems(_ login: RegistryLogin) -> some View {
        Button { copyToPasteboard(login.host) } label: { Label("Copy host", systemImage: "doc.on.doc") }
        Divider()
        Button(role: .destructive) { loggingOut = login } label: { Label("Log out", systemImage: "rectangle.portrait.and.arrow.right") }
    }

    private var logoutBinding: Binding<Bool> {
        Binding(get: { loggingOut != nil }, set: { if !$0 { loggingOut = nil } })
    }

    private func logout(_ login: RegistryLogin) async {
        guard let client = app.client else { return }
        do { _ = try await client.registryLogout(server: login.host); await app.refreshResource(.registries) }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }
}

/// Sign in to a registry. The user types their own credentials; the password is sent via stdin.
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
                    GlassCircleButton(systemName: "checkmark", prominent: true, help: "Log in") { submit() }
                        .disabled(server.trimmingCharacters(in: .whitespaces).isEmpty
                                  || username.trimmingCharacters(in: .whitespaces).isEmpty
                                  || password.isEmpty)
                }
            }
            Form {
                TextField("Server", text: $server, prompt: Text("e.g. ghcr.io, docker.io"))
                    .textContentType(.URL)
                TextField("Username", text: $username, prompt: Text("registry username"))
                    .textContentType(.username)
                SecureField("Password / token", text: $password, prompt: Text("password or access token"))
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
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
                await app.refreshResource(.registries)
                dismiss()
            } catch let e as CommandError { error = e.userMessage; busy = false }
            catch { self.error = error.localizedDescription; busy = false }
        }
    }
}
