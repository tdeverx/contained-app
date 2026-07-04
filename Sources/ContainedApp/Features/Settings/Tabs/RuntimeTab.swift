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
        SettingsForm {
            Section {
                ForEach(app.supportedRuntimeDescriptors, id: \.kind) { descriptor in
                    let reachable = app.availableRuntimeDescriptors.contains { $0.kind == descriptor.kind }
                    UI.Form.Row(title: descriptor.displayName) {
                        Text(reachable ? AppText.string("settings.runtime.reachable", defaultValue: "Reachable")
                             : AppText.string("settings.runtime.notReachable", defaultValue: "Not reachable"))
                            .designSecondaryValueStyle()
                    }
                }
            } header: {
                Text(AppText.string("settings.runtime.available", defaultValue: "Container runtimes"))
            } footer: {
                Text(AppText.runtimeSubtitle)
            }

            Section {
                ForEach(app.supportedRuntimeDescriptors, id: \.kind) { descriptor in
                    runtimePathField(for: descriptor)
                }
            } header: {
                Text(AppText.string("settings.runtime.cliPaths", defaultValue: "Runtime paths"))
            } footer: {
                Text(AppText.string("settings.runtime.cliPaths.footer", defaultValue: "Path overrides are optional. Leave blank to use auto-detection; press Return after changing a path to reconnect."))
            }

            if let descriptor = managementRuntimeDescriptor {
                managementRuntimeControls(for: descriptor)
            }
            ForEach(endpointGuidanceDescriptors, id: \.kind) { descriptor in
                endpointGuidance(for: descriptor)
            }

            if let props = app.properties {
                Section {
                    if let d = props.container {
                        if let c = d.cpus { UI.Form.Row(title: AppText.string("settings.runtime.defaultCPUs", defaultValue: "Default CPUs")) { Text("\(c)").designSecondaryValueStyle() } }
                        if let m = d.memory { UI.Form.Row(title: AppText.string("settings.runtime.defaultMemory", defaultValue: "Default memory")) { Text(m).designSecondaryValueStyle() } }
                    }
                    if let machine = props.machine {
                        if let c = machine.cpus { UI.Form.Row(title: AppText.string("settings.runtime.machineCPUs", defaultValue: "Machine CPUs")) { Text("\(c)").designSecondaryValueStyle() } }
                        if let m = machine.memory { UI.Form.Row(title: AppText.string("settings.runtime.machineMemory", defaultValue: "Machine memory")) { Text(m).designSecondaryValueStyle() } }
                    }
                    if let b = props.build {
                        if let img = b.image { UI.Form.Row(title: AppText.string("settings.runtime.builderImage", defaultValue: "Builder image")) { Text(img).designSecondaryValueStyle() } }
                        if let r = b.rosetta { UI.Form.Row(title: AppText.string("settings.runtime.builderRosetta", defaultValue: "Builder Rosetta")) { Text(r ? "On" : "Off").designSecondaryValueStyle() } }
                    }
                    if let k = props.kernel, let path = k.binaryPath { UI.Form.Row(title: AppText.string("settings.runtime.kernel", defaultValue: "Kernel")) { Text(path).designSecondaryValueStyle() } }
                } header: {
                    Text(AppText.string("settings.runtime.resources", defaultValue: "Runtime resources"))
                } footer: {
                    Text(AppText.string("settings.runtime.resources.footer", defaultValue: "Read-only - machine resources are the denominator for machine-normalized stats. Defaults apply when a container or build doesn't specify its own resources."))
                }
            }
        }
        .task { await loadRuntimeDetails() }
        .confirmationDialog("Install the recommended kernel?", isPresented: $confirmingKernel) {
            Button("Download & install") { Task { await installKernel() } }
        } message: {
            Text("Downloads and sets the recommended kernel as the default. This may take a moment.")
        }
        .confirmationDialog("Delete DNS domain \(deletingDomain ?? "")?",
                            isPresented: deletingDomainBinding, presenting: deletingDomain) { domain in
            Button("Delete", role: .destructive) { Task { await deleteDNS(domain) } }
        } message: { _ in Text("This may prompt for your administrator password (handled by the runtime CLI).") }
        .alert("New local DNS domain", isPresented: $addingDNS) {
            TextField("example.test", text: $newDomain)
            Button("Cancel", role: .cancel) { newDomain = "" }
            Button("Create") { Task { await addDNS() } }
        } message: {
            Text("Creating a domain may prompt for your administrator password (handled by the runtime CLI).")
        }
    }

    private var managementRuntimeDescriptor: Core.Runtime.Descriptor? {
        app.supportedRuntimeDescriptors.first(where: { descriptor in
            app.runtimeIsReady(descriptor.kind) &&
                (descriptor.supports(.kernelManagement) || descriptor.supports(.dnsManagement))
        })
    }

    private var endpointGuidanceDescriptors: [Core.Runtime.Descriptor] {
        app.supportedRuntimeDescriptors.filter { descriptor in
            descriptor.supports(.systemStatus) && !descriptor.supports(.serviceControl)
        }
    }

    @ViewBuilder
    private func managementRuntimeControls(for descriptor: Core.Runtime.Descriptor) -> some View {
        if descriptor.supports(.kernelManagement) {
            Section {
                UI.Form.Row(title: AppText.string("settings.runtime.recommendedKernel", defaultValue: "Recommended kernel")) {
                    Button("Install…") { confirmingKernel = true }
                }
                revealCLIHint("\(descriptor.executableName ?? descriptor.kind.rawValue) system kernel set --recommended")
            } header: {
                Text(AppText.string("settings.runtime.kernel", defaultValue: "Kernel"))
            } footer: {
                Text(AppText.string("settings.runtime.kernel.footer", defaultValue: "Downloads and sets the recommended kernel as the default. May prompt for your administrator password - handled by the runtime CLI; Contained never sees it."))
            }
        }

        if descriptor.supports(.dnsManagement) {
            Section {
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
            } header: {
                Text(AppText.string("settings.runtime.localDNSDomains", defaultValue: "Local DNS domains"))
            } footer: {
                Text(AppText.string("settings.runtime.localDNSDomains.footer", defaultValue: "Creating or deleting a domain may prompt for your administrator password - handled by the runtime CLI."))
            }
        }
    }

    private func endpointGuidance(for descriptor: Core.Runtime.Descriptor) -> some View {
        Section {
            UI.Form.Row(title: AppText.string("settings.runtime.endpointStatus", defaultValue: "Endpoint")) {
                Text(app.availableRuntimeDescriptors.contains(where: { $0.kind == descriptor.kind }) ? AppText.string("settings.runtime.endpointReachable", defaultValue: "Reachable")
                     : AppText.string("settings.runtime.endpointUnavailable", defaultValue: "Unavailable"))
                    .designSecondaryValueStyle()
            }
            Button(AppText.string("common.retry", defaultValue: "Retry")) {
                Task { await app.retryBootstrap() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text("\(descriptor.displayName) endpoint")
        } footer: {
            Text(AppText.string("settings.runtime.endpoint.footer", defaultValue: "Contained talks to this runtime through its CLI and configured endpoint. If the endpoint is unavailable, make sure the provider is running and retry."))
        }
    }

    /// A small copyable CLI hint, shown only when the Reveal-CLI setting is on.
    @ViewBuilder
    private func revealCLIHint(_ command: String) -> some View {
        if app.settings.revealCLI {
            UI.List.MetadataRow(systemImage: "terminal",
                              title: command,
                              isMonospaced: true) {
                UI.Copy.Icon(value: command, help: AppText.copyCommand)
            }
        }
    }

    private var deletingDomainBinding: Binding<Bool> {
        Binding(get: { deletingDomain != nil }, set: { if !$0 { deletingDomain = nil } })
    }

    private func runtimePathField(for descriptor: Core.Runtime.Descriptor) -> some View {
        UI.Form.Field(label: runtimePathLabel(for: descriptor),
                      info: runtimePathInfo(for: descriptor),
                      isChanged: !app.settings.runtimePathOverride(for: descriptor.kind).isEmpty) {
            TextField("", text: runtimePathBinding(for: descriptor.kind),
                      prompt: Text(defaultPathPrompt(for: descriptor)))
                .onSubmit { Task { await app.retryBootstrap() } }
        }
    }

    private func runtimePathLabel(for descriptor: Core.Runtime.Descriptor) -> String {
        "\(descriptor.displayName) CLI path"
    }

    private func runtimePathInfo(for descriptor: Core.Runtime.Descriptor) -> String {
        let executable = descriptor.executableName ?? descriptor.displayName
        return "Override the auto-detected \(executable) binary location."
    }

    private func runtimePathBinding(for kind: Core.Runtime.Kind) -> Binding<String> {
        Binding {
            app.settings.runtimePathOverride(for: kind)
        } set: { value in
            app.settings.setRuntimePathOverride(value, for: kind)
        }
    }

    private func defaultPathPrompt(for descriptor: Core.Runtime.Descriptor) -> String {
        descriptor.executableName.map { "/usr/local/bin/\($0)" } ?? ""
    }

    private func loadRuntimeDetails(force: Bool = false) async {
        if force {
            dnsDomains = []
            await app.reloadProperties()
        } else {
            await app.loadPropertiesIfNeeded()
        }
        if let descriptor = managementRuntimeDescriptor, descriptor.supports(.dnsManagement) {
            await loadDNS(runtimeKind: descriptor.kind)
        }
    }

    private func loadDNS(runtimeKind: Core.Runtime.Kind) async {
        guard app.runtimeIsReady(runtimeKind), let client = app.client else { return }
        if let domains = try? await client.dnsDomains(runtimeKind: runtimeKind) { dnsDomains = domains }
    }

    private func installKernel() async {
        guard let descriptor = managementRuntimeDescriptor,
              descriptor.supports(.kernelManagement),
              let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.setRecommendedKernel(runtimeKind: descriptor.kind) }) { app.flash(error) }
        else { app.flash(AppText.recommendedKernelInstalled); await app.reloadProperties() }
    }

    private func addDNS() async {
        let domain = newDomain.trimmingCharacters(in: .whitespaces)
        newDomain = ""
        guard let descriptor = managementRuntimeDescriptor,
              descriptor.supports(.dnsManagement),
              !domain.isEmpty,
              let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.createDNSDomain(domain, runtimeKind: descriptor.kind) }) { app.flash(error) }
        else { await loadDNS(runtimeKind: descriptor.kind) }
    }

    private func deleteDNS(_ domain: String) async {
        guard let descriptor = managementRuntimeDescriptor,
              descriptor.supports(.dnsManagement),
              let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.deleteDNSDomain(domain, runtimeKind: descriptor.kind) }) { app.flash(error) }
        else { await loadDNS(runtimeKind: descriptor.kind) }
    }
}
