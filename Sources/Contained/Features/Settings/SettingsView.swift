import SwiftUI
import AppKit
import ContainedCore

/// App preferences. Six sections, each built from the same grouped-`Form` + `Section` model so spacing,
/// headers, and explanatory footers stay consistent: Appearance (theme + glass), General (behavior,
/// data, CLI), Runtime, Registries, Updates, and About.
///
/// Hosted in the toolbar Settings morph panel (there's no standalone Settings window). Sections switch
/// via a header menu (page switching) rather than a `TabView` — `NSTabView`'s Auto Layout constraints
/// crash when the morph grow proposes a tiny size. Pass `onClose` to show a close button in the header.
struct SettingsContent: View {
    @Environment(AppModel.self) private var app
    @State private var page: SettingsPage = .appearance
    var onClose: (() -> Void)?

    enum SettingsPage: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case general = "General"
        case runtime = "Runtime"
        case registries = "Registries"
        case updates = "Updates"
        case about = "About"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .appearance: "paintpalette"
            case .general: "gearshape"
            case .runtime: "cpu"
            case .registries: "key"
            case .updates: "arrow.down.app"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        @Bindable var settings = app.settings
        VStack(spacing: 0) {
            header
            Divider()
            sectionBody(settings: settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Drop the grouped-Form backing so the morph panel's glass material shows through —
                // the sections read as inset cards floating on the panel instead of a solid sheet.
                .scrollContentBackground(.hidden)
        }
    }

    private var header: some View {
        ResourceCardHeader {
            GlassButtonItem(systemName: page.systemImage, help: "Settings", isLabel: true)
        } content: {
            VStack(alignment: .leading, spacing: 1) {
                Text("Settings").font(.headline)
                Text(page.rawValue).font(.caption).foregroundStyle(.secondary)
            }
        } trailing: {
            GlassButton(singleItem: onClose == nil) {
                pagePicker
                if let onClose {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                }
            }
        }
        .padding(Tokens.Space.m)
    }

    private var pagePicker: some View {
        Menu {
            ForEach(SettingsPage.allCases) { item in
                Button { page = item } label: { Label(item.rawValue, systemImage: item.systemImage) }
            }
        } label: {
            GlassButtonItem(systemName: "list.bullet", help: "Section", isLabel: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionBody(settings: SettingsStore) -> some View {
        switch page {
        case .appearance: AppearanceTab(settings: settings)
        case .general: GeneralTab(settings: settings)
        case .runtime: RuntimeTab()
        case .registries: RegistriesTab()
        case .updates: UpdatesTab()
        case .about: AboutTab()
        }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Accent tint") {
                    TintSelector(selection: $settings.accentTint)
                }
            }

            Section {
                Picker("Card size", selection: $settings.density) {
                    ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Main background material", selection: $settings.windowMaterial) {
                    ForEach(WindowMaterial.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Panel & sheet material", selection: $settings.modalMaterial) {
                    ForEach(WindowMaterial.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Reduce translucency", isOn: $settings.reduceTranslucency)
                Toggle("Show info tips", isOn: $settings.showInfoTips)
            } header: {
                Text("Layout & glass")
            } footer: {
                Text("Main background material controls the root content backing. Panel & sheet material controls floating detail panels, popovers, and sheets. Reduce translucency switches to solid system surfaces for legibility.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Environment(AppModel.self) private var app
    @Bindable var settings: SettingsStore
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Keep running in the menu bar", isOn: $settings.keepInMenuBar)
            }

            Section("Activity & alerts") {
                Toggle("System alert on container crash / restart", isOn: $settings.notifyOnCrash)
                Toggle("Show “Reveal CLI” on actions", isOn: $settings.revealCLI)
                    .fieldInfo("Adds a copyable command and a “Copy as CLI” menu item to destructive or privileged actions, so you can see exactly what runs.")
            }

            Section {
                LabeledContent("Refresh interval") {
                    HStack {
                        Slider(value: $settings.refreshInterval, in: 1...10, step: 1)
                        Text("\(Int(settings.refreshInterval))s").monospacedDigit().frame(width: 32, alignment: .trailing)
                    }
                }
                Picker("Keep history for", selection: retentionBinding) {
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }
                Button("Clear History…", role: .destructive) { confirmingClear = true }
                ConfigTransferControls()
            } header: {
                Text("Data")
            } footer: {
                Text("Backups use a versioned JSON envelope, so settings and local data can be exported before rollback or restored after upgrade.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Advanced") {
                TextField("Container CLI path", text: $settings.cliPathOverride,
                          prompt: Text("/usr/local/bin/container"))
                    .fieldInfo("Override the auto-detected `container` binary location.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Clear all history?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { app.clearHistory() }
        } message: {
            Text("This permanently removes all recorded metrics and events. Saved templates are kept.")
        }
    }

    private var retentionBinding: Binding<Int> {
        Binding(get: { settings.historyRetentionDays },
                set: { app.applyHistoryRetention($0) })
    }
}

// MARK: - Runtime

/// Daemon runtime configuration: the editable bits (recommended kernel, local DNS domains) plus a
/// read-only view of the daemon defaults. Defaults are read-only because the `container` CLI exposes
/// no setter for them — `system property` only lists; only the kernel and DNS are settable.
private struct RuntimeTab: View {
    @Environment(AppModel.self) private var app
    @State private var dnsDomains: [String] = []
    @State private var confirmingKernel = false
    @State private var addingDNS = false
    @State private var newDomain = ""
    @State private var deletingDomain: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Recommended kernel") {
                    Button("Install…") { confirmingKernel = true }
                }
                revealCLIHint("container system kernel set --recommended")
            } header: {
                Text("Kernel")
            } footer: {
                Text("Downloads and sets the recommended kernel as the default. May prompt for your administrator password — handled by the container CLI; Contained never sees it.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                if dnsDomains.isEmpty {
                    Text("No local DNS domains.").foregroundStyle(.secondary)
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
            } header: {
                Text("Local DNS domains")
            } footer: {
                Text("Creating or deleting a domain may prompt for your administrator password — handled by the container CLI.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let props = app.properties {
                Section {
                    if let d = props.container {
                        if let c = d.cpus { LabeledContent("Default CPUs", value: "\(c)") }
                        if let m = d.memory { LabeledContent("Default memory", value: m) }
                    }
                    if let b = props.build {
                        if let img = b.image { LabeledContent("Builder image", value: img) }
                        if let r = b.rosetta { LabeledContent("Builder Rosetta", value: r ? "On" : "Off") }
                    }
                    if let k = props.kernel, let path = k.binaryPath { LabeledContent("Kernel", value: path) }
                } header: {
                    Text("Defaults")
                } footer: {
                    Text("Read-only — the container runtime provides no command to change these. They apply when a container or build doesn’t specify its own resources.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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

// MARK: - Registries

/// Registry logins live here (not the File menu): list signed-in registries and log in / out. This
/// is the credential-management home now that the Registries sidebar page is gone.
private struct RegistriesTab: View {
    @Environment(AppModel.self) private var app
    @State private var loggingIn = false
    @State private var loggingOut: RegistryLogin?

    var body: some View {
        Form {
            Section {
                if app.registries.isEmpty {
                    Text("Not signed in to any registries.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(app.registries) { login in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(login.host)
                                if let user = login.username {
                                    Text("as \(user)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Log Out", role: .destructive) { loggingOut = login }
                        }
                    }
                }
            } header: {
                Text("Signed-in registries")
            } footer: {
                Text("Credentials are typed by you and piped to the CLI via stdin, so the password never lands in the process list. Contained doesn’t store it.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Button("Log In to Registry…") { loggingIn = true }
            }
        }
        .formStyle(.grouped)
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

// MARK: - Updates

private struct UpdatesTab: View {
    @Environment(AppModel.self) private var app
    @State private var showingAvailableNotes = false
    @State private var showingCurrentNotes = false

    var body: some View {
        @Bindable var settings = app.settings
        Form {
            Section {
                LabeledContent("Update channel") {
                    Menu(app.settings.updateChannel.displayName) {
                        ForEach(UpdateChannel.allCases) { channel in
                            Button {
                                channelBinding.wrappedValue = channel
                            } label: {
                                if app.settings.updateChannel == channel {
                                    Label(channel.displayName, systemImage: "checkmark")
                                } else {
                                    Text(channel.displayName)
                                }
                            }
                            .disabled(!app.updater.availableChannels.contains(channel))
                        }
                    }
                    .fixedSize()
                }
                Toggle("Automatically check for updates",
                       isOn: Binding(get: { app.updater.automaticallyChecks },
                                     set: { app.updater.automaticallyChecks = $0 }))
                Button("Check for Updates…") { app.updater.checkForUpdates() }
                    .disabled(!app.updater.canCheckForUpdates)
                Button("What’s New in This Build") { showingCurrentNotes = true }
                Button("What’s New in Available Update") { showingAvailableNotes = true }
                    .disabled(app.updater.availableReleaseNotesHTML == nil)
            } header: {
                Text("Updates")
            } footer: {
                Text("\(settings.updateChannel.footnote) Each channel has its own release feed; channels without a published build yet are dimmed and unselectable. Delivered via Sparkle once a signed build points at the feed; inert in development builds.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker("Check images", selection: $settings.imageUpdateIntervalHours) {
                    Text("Every hour").tag(1)
                    Text("Every 3 hours").tag(3)
                    Text("Every 6 hours").tag(6)
                    Text("Every 12 hours").tag(12)
                    Text("Every day").tag(24)
                }
            } header: {
                Text("Image updates")
            } footer: {
                Text("Controls the background registry digest check cadence. Manual checks are always available from Images, System, and the toolbar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { app.updater.refreshChannelAvailability() }
        .sheet(isPresented: $showingCurrentNotes) {
            ReleaseNotesView(title: "What’s New", html: app.updater.currentReleaseNotesHTML)
        }
        .sheet(isPresented: $showingAvailableNotes) {
            ReleaseNotesView(title: "Available Update",
                             html: app.updater.availableReleaseNotesHTML ?? "<p>No release notes are available.</p>")
        }
    }

    private var channelBinding: Binding<UpdateChannel> {
        Binding(get: { app.settings.updateChannel },
                set: { app.settings.updateChannel = $0; app.updater.channel = $0 })
    }
}

// MARK: - About

private struct AboutTab: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Form {
            Section {
                HStack(spacing: Tokens.Space.m) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contained").font(.title3.weight(.semibold))
                        Text("Version \(appVersion)").font(.callout).foregroundStyle(.secondary)
                        Text("A native macOS UI for Apple’s container runtime.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, Tokens.Space.xs)
            }

            Section("Runtime") {
                LabeledContent("Container CLI", value: app.cliVersion ?? "—")
                LabeledContent("API server", value: app.systemStatus?.apiServerVersion ?? "—")
            }

            Section {
                LabeledContent("Copyright", value: "© 2026 Contained")
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
