import SwiftUI
import AppKit
import ContainedCore

/// App preferences. Four tabs, each built from the same grouped-`Form` + `Section` model so spacing,
/// headers, and explanatory footers stay consistent: Appearance (theme + glass), General (behavior,
/// data, CLI), Updates (Sparkle), and About.
struct SettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var settings = app.settings
        TabView {
            AppearanceTab(settings: settings)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            UpdatesTab()
                .tabItem { Label("Updates", systemImage: "arrow.down.app") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 460)
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
                Picker("Window backdrop", selection: $settings.backdrop) {
                    ForEach(BackdropStyle.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Reduce translucency", isOn: $settings.reduceTranslucency)
            } header: {
                Text("Layout & glass")
            } footer: {
                Text("Reduce translucency falls back to solid surfaces — useful on slower displays or for legibility. Per-container colors are set from each container's Customize sheet.")
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

            Section("Notifications & actions") {
                Toggle("Notify on container crash / restart", isOn: $settings.notifyOnCrash)
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
            } header: {
                Text("Data")
            } footer: {
                Text("How often running containers are polled, and how long persistent metrics & events are kept before pruning.")
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

// MARK: - Updates

private struct UpdatesTab: View {
    @Environment(AppModel.self) private var app

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
            } header: {
                Text("Updates")
            } footer: {
                Text("\(settings.updateChannel.footnote) Each channel has its own release feed; channels without a published build yet are dimmed and unselectable. Delivered via Sparkle once a signed build points at the feed; inert in development builds.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { app.updater.refreshChannelAvailability() }
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
