import SwiftUI
import AppKit
import ContainedCore

/// App preferences. Six sections, each built from the same `PanelSection` glass-card model so spacing,
/// headers, and explanatory footers stay consistent: Appearance (theme + glass), General (behavior,
/// data, CLI), Runtime, Registries, Updates, and About.
///
/// Hosted in the toolbar Settings morph panel via the shared `MorphPanelScaffold`, so the panel hugs
/// the active section's content height. Sections switch via a header menu rather than a `TabView`.
struct SettingsContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
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
        MorphPanelScaffold(width: Tokens.PanelSize.settings.width, placement: .centered) {
            VStack(spacing: 0) {
                header
                Divider()
            }
        } content: {
            sectionBody(settings: settings)
                .padding(Tokens.Space.l)
        }
        .onChange(of: ui.settingsPage) { _, requested in
            guard let requested else { return }
            page = requested
            ui.settingsPage = nil
        }
    }

    private var header: some View {
        PanelHeader(symbol: page.systemImage,
                    title: "Settings",
                    subtitle: page.rawValue) {
            GlassButton(singleItem: onClose == nil) {
                pagePicker
                if let onClose {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                }
            }
        }
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
        VStack(spacing: Tokens.Space.l) {
            PanelSection(header: "Theme") {
                PanelRow(title: "Appearance") {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                PanelRow(title: "Accent tint") {
                    TintSelector(selection: $settings.accentTint)
                }
            }

            PanelSection(header: "Layout & glass",
                         footer: "Main background material controls the root content backing. Panel & sheet material controls floating detail panels, popovers, and sheets. Button material controls the toolbar control surfaces. “Glass (Clear)” and “Glass (Regular)” use Liquid Glass; the rest are system vibrancy materials.") {
                PanelRow(title: "Card size") {
                    Picker("", selection: $settings.density) {
                        ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                PanelRow(title: "Main background material") {
                    materialMenu($settings.windowMaterial)
                }
                PanelRow(title: "Panel & sheet material") {
                    materialMenu($settings.modalMaterial)
                }
                PanelRow(title: "Button material") {
                    materialMenu($settings.buttonMaterial)
                }
                PanelToggleRow(title: "Show info tips", isOn: $settings.showInfoTips)
            }

            ImageDefaultStyleSection(settings: settings)
        }
    }

    private func materialMenu(_ binding: Binding<WindowMaterial>) -> some View {
        Picker("", selection: binding) {
            ForEach(WindowMaterial.allCases) { Text($0.displayName).tag($0) }
        }
        .labelsHidden().fixedSize()
    }
}

private struct ImageDefaultStyleSection: View {
    @Environment(AppModel.self) private var app
    @Bindable var settings: SettingsStore

    private var style: Personalization { app.personalization.defaultImageStyle }

    var body: some View {
        PanelSection(header: "Default image cards",
                     footer: "When on, image groups, image rows, and containers without their own style inherit this design. Specific image, image-group, tag, and container styles remain local overrides above this default.",
                     enabled: $settings.imageDefaultStyleEnabled) {
            HStack(spacing: Tokens.Space.m) {
                ResourceCardIconChip(symbol: style.symbol, tint: style.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.displayName(fallback: "Image cards"))
                    Text("Inherited unless an image, group, tag, or container overrides it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            PanelRow(title: "Color") {
                TintSelector(selection: styleBinding(\.tint))
            }
            PanelToggleRow(title: "Custom icon", isOn: styleBinding(\.iconEnabled))
            if style.iconEnabled {
                PanelRow(title: "Icon") {
                    TextField("", text: styleBinding(\.icon), prompt: Text("SF Symbol, e.g. shippingbox.fill"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }
            PanelToggleRow(title: "Color the card background", isOn: styleBinding(\.fillBackground))
            if style.fillBackground {
                PanelRow(title: "Opacity") {
                    HStack(spacing: Tokens.Space.s) {
                        Slider(value: styleBinding(\.backgroundOpacity), in: 0.05...0.6).frame(width: 140)
                        Text(Format.percent(style.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: Tokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: "Gradient", isOn: styleBinding(\.gradient))
                if style.gradient {
                    GradientAngleControl(angle: styleBinding(\.gradientAngle))
                }
            }
        }
    }

    private func styleBinding<Value>(_ keyPath: WritableKeyPath<Personalization, Value>) -> Binding<Value> {
        Binding {
            app.personalization.defaultImageStyle[keyPath: keyPath]
        } set: { newValue in
            var updated = app.personalization.defaultImageStyle
            updated[keyPath: keyPath] = newValue
            app.personalization.setDefaultImageStyle(updated)
        }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Environment(AppModel.self) private var app
    @Bindable var settings: SettingsStore
    @State private var confirmingClear = false

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection(header: "Startup") {
                PanelToggleRow(title: "Launch at login", isOn: $settings.launchAtLogin)
                PanelToggleRow(title: "Keep running in the menu bar", isOn: $settings.keepInMenuBar)
            }

            PanelSection(header: "Activity & alerts") {
                PanelToggleRow(title: "System alert on container crash / restart", isOn: $settings.notifyOnCrash)
                PanelToggleRow(title: "Show “Reveal CLI” on actions",
                               info: "Adds a copyable command and a “Copy as CLI” menu item to destructive or privileged actions, so you can see exactly what runs.",
                               isOn: $settings.revealCLI)
            }

            PanelSection(header: "Data",
                         footer: "How often running containers are polled, and how long persistent metrics & events are kept before pruning.") {
                PanelRow(title: "Refresh interval") {
                    HStack(spacing: Tokens.Space.s) {
                        Slider(value: $settings.refreshInterval, in: 1...10, step: 1).frame(width: 140)
                        Text("\(Int(settings.refreshInterval))s").monospacedDigit().frame(width: 32, alignment: .trailing)
                    }
                }
                PanelRow(title: "Keep history for") {
                    Picker("", selection: retentionBinding) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                    .labelsHidden().fixedSize()
                }
                Button("Clear History…", role: .destructive) { confirmingClear = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                ConfigTransferControls()
            }

            PanelSection(header: "Logging",
                         footer: settings.loggingLevel.footnote) {
                PanelRow(title: "Level") {
                    Picker("", selection: $settings.loggingLevel) {
                        ForEach(AppLogLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                VStack(alignment: .leading, spacing: Tokens.Space.s) {
                    Text("Write to").font(.caption).foregroundStyle(.secondary)
                    ForEach(AppLogDestination.allCases) { destination in
                        Toggle(destination.displayName, isOn: setBinding(destination, in: \.enabledLogDestinations))
                            .toggleStyle(.checkbox)
                    }
                }
                VStack(alignment: .leading, spacing: Tokens.Space.s) {
                    Text("Categories").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)],
                              alignment: .leading,
                              spacing: Tokens.Space.s) {
                        ForEach(AppLogCategory.allCases) { category in
                            Toggle(category.displayName, isOn: setBinding(category, in: \.enabledLogCategories))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
            }

            PanelSection(header: "Advanced") {
                PanelField(label: "Container CLI path",
                           info: "Override the auto-detected `container` binary location.") {
                    TextField("", text: $settings.cliPathOverride, prompt: Text("/usr/local/bin/container"))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
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

    private func setBinding<T>(_ value: T, in keyPath: ReferenceWritableKeyPath<SettingsStore, Set<T>>) -> Binding<Bool> where T: Hashable {
        Binding {
            settings[keyPath: keyPath].contains(value)
        } set: { isEnabled in
            var values = settings[keyPath: keyPath]
            if isEnabled { values.insert(value) }
            else { values.remove(value) }
            settings[keyPath: keyPath] = values
        }
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

// MARK: - Registries

/// Registry logins live here: list signed-in registries and log in / out.
private struct RegistriesTab: View {
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

// MARK: - Updates

private struct UpdatesTab: View {
    @Environment(AppModel.self) private var app
    @State private var showingAvailableNotes = false
    @State private var showingCurrentNotes = false

    var body: some View {
        @Bindable var settings = app.settings
        VStack(spacing: Tokens.Space.l) {
            PanelSection(header: "Updates",
                         footer: "\(settings.updateChannel.footnote) Each channel has its own release feed; channels without a published build yet are dimmed and unselectable. Delivered via Sparkle once a signed build points at the feed; inert in development builds.") {
                PanelRow(title: "Update channel") {
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
                PanelToggleRow(title: "Automatically check for updates",
                               isOn: Binding(get: { app.updater.automaticallyChecks },
                                             set: { app.updater.automaticallyChecks = $0 }))
                Button("Check for Updates…") { app.updater.checkForUpdates() }
                    .disabled(!app.updater.canCheckForUpdates)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("What’s New in This Build") { showingCurrentNotes = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("What’s New in Available Update") { showingAvailableNotes = true }
                    .disabled(app.updater.availableReleaseNotesHTML == nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PanelSection(header: "Image updates",
                         footer: "Controls the background registry digest check cadence. Manual checks are always available from Images, System, and the toolbar.") {
                PanelRow(title: "Check images") {
                    Picker("", selection: $settings.imageUpdateIntervalHours) {
                        Text("Every hour").tag(1)
                        Text("Every 3 hours").tag(3)
                        Text("Every 6 hours").tag(6)
                        Text("Every 12 hours").tag(12)
                        Text("Every day").tag(24)
                    }
                    .labelsHidden().fixedSize()
                }
            }
        }
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
        VStack(spacing: Tokens.Space.l) {
            PanelSection {
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
            }

            PanelSection(header: "Runtime") {
                PanelRow(title: "Container CLI") { Text(app.cliVersion ?? "—").foregroundStyle(.secondary) }
                PanelRow(title: "API server") { Text(app.systemStatus?.apiServerVersion ?? "—").foregroundStyle(.secondary) }
            }

            PanelSection {
                PanelRow(title: "Copyright") { Text("© 2026 Contained").foregroundStyle(.secondary) }
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
