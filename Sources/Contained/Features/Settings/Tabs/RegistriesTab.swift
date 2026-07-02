import SwiftUI
import ContainedDesignSystem
import ContainedCore

// MARK: - Registries

/// Registry logins live here: list signed-in registries and log in / out.
struct RegistriesTab: View {
    @Environment(AppModel.self) private var app
    @State private var loggingIn = false
    @State private var loggingOut: RegistryLogin?

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection(header: "Signed-in registries",
                         footer: "Credentials are typed by you and piped to the CLI via stdin, so the password never lands in the process list. Contained doesn’t store it.") {
                if app.registries.isEmpty {
                    Text("Not signed in to any registries.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(app.registries) { login in
                        HStack {
                            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                                Text(login.host)
                                if let user = login.username {
                                    Text("as \(user)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Log Out", role: .destructive) { loggingOut = login }
                        }
                        .contextMenu {
                            Button { copyToPasteboard(login.host) } label: { Label("Copy Server", systemImage: "doc.on.doc") }
                            Divider()
                            Button(role: .destructive) { loggingOut = login } label: { Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right") }
                        }
                    }
                }
            }

            PanelSection {
                Button("Log In to Registry…") { loggingIn = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task { await app.refreshRegistries() }
        .sheet(isPresented: $loggingIn) { RegistryLoginSheet() }
        .confirmationDialog("Log out of \(loggingOut?.host ?? "")?",
                            isPresented: logoutBinding, presenting: loggingOut) { login in
            Button("Log out", role: .destructive) { Task { await logout(login) } }
        } message: { _ in Text("Removes the stored credentials for this registry.") }
    }

    private var logoutBinding: Binding<Bool> {
        Binding(get: { loggingOut != nil }, set: { if !$0 { loggingOut = nil } })
    }

    private func logout(_ login: RegistryLogin) async {
        guard let client = app.client else { return }
        do { _ = try await client.registryLogout(server: login.host); await app.refreshRegistries() }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }
}
