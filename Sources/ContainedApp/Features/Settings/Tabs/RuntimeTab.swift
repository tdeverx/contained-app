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
        @Bindable var settings = app.settings
        LazyVStack(spacing: UI.Layout.Spacing.l) {
            UI.Panel.Section(header: AppText.string("settings.runtime.available", defaultValue: "Container runtimes"),
                             footer: AppText.runtimeSubtitle) {
                ForEach(app.supportedRuntimeDescriptors, id: \.kind) { descriptor in
                    let reachable = app.availableRuntimeDescriptors.contains { $0.kind == descriptor.kind }
                    UI.Panel.Row(title: descriptor.displayName) {
                        Text(reachable ? AppText.string("settings.runtime.reachable", defaultValue: "Reachable")
                             : AppText.string("settings.runtime.notReachable", defaultValue: "Not reachable"))
                            .designSecondaryValueStyle()
                    }
                }
            }

            UI.Panel.Section(header: AppText.string("settings.runtime.cliPaths", defaultValue: "Runtime paths"),
                             footer: AppText.string("settings.runtime.cliPaths.footer", defaultValue: "Path overrides are optional. Leave blank to use auto-detection; press Return after changing a path to reconnect.")) {
                ForEach(app.supportedRuntimeDescriptors, id: \.kind) { descriptor in
                    runtimePathField(for: descriptor)
                }
            }

            if app.appleRuntimeReady {
                appleRuntimeControls
            }
            if app.supportedRuntimeDescriptors.contains(where: { $0.kind == .docker }) {
                dockerRuntimeGuidance
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
        .task { await loadRuntimeDetails() }
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

    @ViewBuilder
    private var appleRuntimeControls: some View {
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
    }

    private var dockerRuntimeGuidance: some View {
        UI.Panel.Section(header: AppText.string("settings.runtime.dockerEndpoint", defaultValue: "Docker endpoint"),
                         footer: AppText.string("settings.runtime.dockerEndpoint.footer", defaultValue: "Contained talks to the Docker CLI and its configured endpoint. If Docker is not reachable, start Docker externally and retry.")) {
            UI.Panel.Row(title: AppText.string("settings.runtime.endpointStatus", defaultValue: "Endpoint")) {
                Text(app.availableRuntimeDescriptors.contains(where: { $0.kind == .docker }) ? AppText.string("settings.runtime.endpointReachable", defaultValue: "Reachable")
                     : AppText.string("settings.runtime.endpointUnavailable", defaultValue: "Unavailable"))
                    .designSecondaryValueStyle()
            }
            Button(AppText.string("common.retry", defaultValue: "Retry")) {
                Task { await app.retryBootstrap() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        UI.Panel.Field(label: runtimePathLabel(for: descriptor),
                       info: runtimePathInfo(for: descriptor)) {
            TextField("", text: runtimePathBinding(for: descriptor.kind),
                      prompt: Text(defaultPathPrompt(for: descriptor)))
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await app.retryBootstrap() } }
        }
    }

    private func runtimePathLabel(for descriptor: Core.Runtime.Descriptor) -> String {
        switch descriptor.kind {
        case .appleContainer:
            return AppText.string("settings.runtime.path.appleContainer", defaultValue: "Apple container CLI path")
        case .docker:
            return AppText.string("settings.runtime.path.docker", defaultValue: "Docker CLI path")
        default:
            return "\(descriptor.displayName) CLI path"
        }
    }

    private func runtimePathInfo(for descriptor: Core.Runtime.Descriptor) -> String {
        switch descriptor.kind {
        case .appleContainer:
            return AppText.string("settings.runtime.path.info.appleContainer",
                                  defaultValue: "Override the auto-detected container binary location.")
        case .docker:
            return AppText.string("settings.runtime.path.info.docker",
                                  defaultValue: "Override the auto-detected docker binary location.")
        default:
            let executable = descriptor.executableName ?? descriptor.displayName
            return "Override the auto-detected \(executable) binary location."
        }
    }

    private func runtimePathBinding(for kind: Core.Runtime.Kind) -> Binding<String> {
        Binding {
            switch kind {
            case .appleContainer: app.settings.cliPathOverride
            case .docker: app.settings.dockerCLIPathOverride
            default: ""
            }
        } set: { value in
            switch kind {
            case .appleContainer: app.settings.cliPathOverride = value
            case .docker: app.settings.dockerCLIPathOverride = value
            default: break
            }
        }
    }

    private func defaultPathPrompt(for descriptor: Core.Runtime.Descriptor) -> String {
        switch descriptor.kind {
        case .appleContainer: return "/usr/local/bin/container"
        case .docker: return "/usr/local/bin/docker"
        default: return descriptor.executableName.map { "/usr/local/bin/\($0)" } ?? ""
        }
    }

    private func loadRuntimeDetails(force: Bool = false) async {
        if force {
            dnsDomains = []
            await app.reloadProperties()
        } else {
            await app.loadPropertiesIfNeeded()
        }
        if app.appleRuntimeReady {
            await loadDNS()
        }
    }

    private func loadDNS() async {
        guard app.appleRuntimeReady, let client = app.client else { return }
        if let domains = try? await client.dnsDomains(runtimeKind: .appleContainer) { dnsDomains = domains }
    }

    private func installKernel() async {
        guard app.appleRuntimeReady, let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.setRecommendedKernel(runtimeKind: .appleContainer) }) { app.flash(error) }
        else { app.flash(AppText.recommendedKernelInstalled); await app.reloadProperties() }
    }

    private func addDNS() async {
        let domain = newDomain.trimmingCharacters(in: .whitespaces)
        newDomain = ""
        guard app.appleRuntimeReady, !domain.isEmpty, let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.createDNSDomain(domain, runtimeKind: .appleContainer) }) { app.flash(error) }
        else { await loadDNS() }
    }

    private func deleteDNS(_ domain: String) async {
        guard app.appleRuntimeReady, let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.deleteDNSDomain(domain, runtimeKind: .appleContainer) }) { app.flash(error) }
        else { await loadDNS() }
    }
}
