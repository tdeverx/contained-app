import SwiftUI
import ContainedUI
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
        LazyVStack(spacing: UI.Layout.Spacing.l) {
            UI.Panel.Section(header: AppText.string("settings.runtime.kernel", defaultValue: "Kernel"),
                         footer: AppText.string("settings.runtime.kernel.footer", defaultValue: "Downloads and sets the recommended kernel as the default. May prompt for your administrator password - handled by the container CLI; Contained never sees it.")) {
                UI.Panel.Row(title: AppText.string("settings.runtime.recommendedKernel", defaultValue: "Recommended kernel")) {
                    Button("Install…") { confirmingKernel = true }
                }
                revealCLIHint("container system kernel set --recommended")
            }

            UI.Panel.Section(header: AppText.string("settings.runtime.localDNSDomains", defaultValue: "Local DNS domains"),
                         footer: AppText.string("settings.runtime.localDNSDomains.footer", defaultValue: "Creating or deleting a domain may prompt for your administrator password - handled by the container CLI.")) {
                if dnsDomains.isEmpty {
                    Text("No local DNS domains.")
                        .designSecondaryValueStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(dnsDomains, id: \.self) { domain in
                        UI.List.MetadataRow(systemImage: "network",
                                          title: domain,
                                          isMonospaced: true) {
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
                UI.Panel.Section(header: AppText.string("settings.runtime.resources", defaultValue: "Runtime resources"),
                             footer: AppText.string("settings.runtime.resources.footer", defaultValue: "Read-only - machine resources are the denominator for machine-normalized stats. Defaults apply when a container or build doesn't specify its own resources.")) {
                    if let d = props.container {
                        if let c = d.cpus { UI.Panel.Row(title: AppText.string("settings.runtime.defaultCPUs", defaultValue: "Default CPUs")) { Text("\(c)").designSecondaryValueStyle() } }
                        if let m = d.memory { UI.Panel.Row(title: AppText.string("settings.runtime.defaultMemory", defaultValue: "Default memory")) { Text(m).designSecondaryValueStyle() } }
                    }
                    if let machine = props.machine {
                        if let c = machine.cpus { UI.Panel.Row(title: AppText.string("settings.runtime.machineCPUs", defaultValue: "Machine CPUs")) { Text("\(c)").designSecondaryValueStyle() } }
                        if let m = machine.memory { UI.Panel.Row(title: AppText.string("settings.runtime.machineMemory", defaultValue: "Machine memory")) { Text(m).designSecondaryValueStyle() } }
                    }
                    if let b = props.build {
                        if let img = b.image { UI.Panel.Row(title: AppText.string("settings.runtime.builderImage", defaultValue: "Builder image")) { Text(img).designSecondaryValueStyle() } }
                        if let r = b.rosetta { UI.Panel.Row(title: AppText.string("settings.runtime.builderRosetta", defaultValue: "Builder Rosetta")) { Text(r ? "On" : "Off").designSecondaryValueStyle() } }
                    }
                    if let k = props.kernel, let path = k.binaryPath { UI.Panel.Row(title: AppText.string("settings.runtime.kernel", defaultValue: "Kernel")) { Text(path).designSecondaryValueStyle() } }
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
            UI.List.MetadataRow(systemImage: "terminal",
                              title: command,
                              isMonospaced: true) {
                Button { copyToPasteboard(command) } label: {
                    UI.Symbol.Image(systemName: "doc.on.doc")
                }
                    .buttonStyle(.borderless)
                    .help(AppText.copyCommand)
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
        else { app.flash(AppText.recommendedKernelInstalled); await app.reloadProperties() }
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
