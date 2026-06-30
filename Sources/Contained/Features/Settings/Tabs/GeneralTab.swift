import SwiftUI
import ContainedCore

// MARK: - General

struct GeneralTab: View {
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
                               info: "Shows the exact `container ...` command for important actions. Useful when you are learning the CLI or want to verify what will run.",
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
