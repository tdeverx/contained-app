import SwiftUI
import ContainedCore

// MARK: - Runtime

/// Daemon runtime configuration: the editable bits (recommended kernel, local DNS domains) plus a
/// read-only view of the daemon defaults. Defaults are read-only because the `container` CLI exposes
/// no setter for them — `system property` only lists; only the kernel and DNS are settable.
struct RuntimeTab: View {
    @Environment(AppModel.self) private var app
    @State private var dnsDomains: [String] = []
    @State private var confirmingKernel = false
    @State private var addingDNS = false
    @State private var newDomain = ""
    @State private var deletingDomain: String?

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection(header: "Kernel",
                         footer: "Downloads and sets the recommended kernel as the default. May prompt for your administrator password — handled by the container CLI; Contained never sees it.") {
                PanelRow(title: "Recommended kernel") {
                    Button("Install…") { confirmingKernel = true }
                }
                revealCLIHint("container system kernel set --recommended")
            }

            PanelSection(header: "Local DNS domains",
                         footer: "Creating or deleting a domain may prompt for your administrator password — handled by the container CLI.") {
                if dnsDomains.isEmpty {
                    Text("No local DNS domains.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(dnsDomains, id: \.self) { domain in
                        HStack {
                            Text(domain).font(.system(.callout, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) { deletingDomain = domain } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Add Domain…") { newDomain = ""; addingDNS = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let props = app.properties {
                PanelSection(header: "Defaults",
                             footer: "Read-only — the container runtime provides no command to change these. They apply when a container or build doesn’t specify its own resources.") {
                    if let d = props.container {
                        if let c = d.cpus { PanelRow(title: "Default CPUs") { Text("\(c)").foregroundStyle(.secondary) } }
                        if let m = d.memory { PanelRow(title: "Default memory") { Text(m).foregroundStyle(.secondary) } }
                    }
                    if let b = props.build {
                        if let img = b.image { PanelRow(title: "Builder image") { Text(img).foregroundStyle(.secondary) } }
                        if let r = b.rosetta { PanelRow(title: "Builder Rosetta") { Text(r ? "On" : "Off").foregroundStyle(.secondary) } }
                    }
                    if let k = props.kernel, let path = k.binaryPath { PanelRow(title: "Kernel") { Text(path).foregroundStyle(.secondary) } }
                }
            }
        }
        .task { await app.loadPropertiesIfNeeded(); await loadDNS() }
        .confirmationDialog("Install the recommended kernel?", isPresented: $confirmingKernel) {
            Button("Download & install") { Task { await installKernel() } }
        } message: {
            Text("Downloads and sets the recommended kernel as the default. This may take a moment.")
        }
        .confirmationDialog("Delete DNS domain \(deletingDomain ?? "")?",
                            isPresented: deletingDomainBinding, presenting: deletingDomain) { domain in
            Button("Delete", role: .destructive) { Task { await deleteDNS(domain) } }
        } message: { _ in Text("This may prompt for your administrator password (handled by the container CLI).") }
        .alert("New local DNS domain", isPresented: $addingDNS) {
            TextField("example.test", text: $newDomain)
            Button("Cancel", role: .cancel) { newDomain = "" }
            Button("Create") { Task { await addDNS() } }
        } message: {
            Text("Creating a domain may prompt for your administrator password (handled by the container CLI).")
        }
    }

    /// A small copyable CLI hint, shown only when the Reveal-CLI setting is on.
    @ViewBuilder
    private func revealCLIHint(_ command: String) -> some View {
        if app.settings.revealCLI {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "terminal").foregroundStyle(.secondary)
                Text(command).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button { copyToPasteboard(command) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary).help("Copy command")
            }
        }
    }

    private var deletingDomainBinding: Binding<Bool> {
        Binding(get: { deletingDomain != nil }, set: { if !$0 { deletingDomain = nil } })
    }

    private func loadDNS() async {
        guard let client = app.client else { return }
        if let domains = try? await client.dnsDomains() { dnsDomains = domains }
    }

    private func installKernel() async {
        guard let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.setRecommendedKernel() }) { app.flash(error) }
        else { app.flash("Recommended kernel installed"); await app.reloadProperties() }
    }

    private func addDNS() async {
        let domain = newDomain.trimmingCharacters(in: .whitespaces)
        newDomain = ""
        guard !domain.isEmpty, let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.createDNSDomain(domain) }) { app.flash(error) }
        else { await loadDNS() }
    }

    private func deleteDNS(_ domain: String) async {
        guard let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.deleteDNSDomain(domain) }) { app.flash(error) }
        else { await loadDNS() }
    }
}

