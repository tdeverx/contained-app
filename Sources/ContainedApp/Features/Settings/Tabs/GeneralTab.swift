import SwiftUI
import ContainedUI
import ContainedCore

// MARK: - General

struct GeneralTab: View {
    @Environment(AppModel.self) private var app
    @Bindable var settings: SettingsStore
    @State private var confirmingClear = false

    var body: some View {
        SettingsForm {
            Section(AppText.string("settings.general.startup", defaultValue: "Startup")) {
                UI.Form.ToggleRow(title: AppText.string("settings.general.launchAtLogin", defaultValue: "Launch at login"),
                                  isOn: $settings.launchAtLogin)
                UI.Form.ToggleRow(title: AppText.string("settings.general.keepInMenuBar", defaultValue: "Keep running in the menu bar"),
                                  isChanged: settings.keepInMenuBar != true,
                                  isOn: $settings.keepInMenuBar)
            }

            Section(AppText.string("settings.general.activityAlerts", defaultValue: "Activity & alerts")) {
                UI.Form.ToggleRow(title: AppText.string("settings.general.notifyOnCrash", defaultValue: "System alert on container crash / restart"),
                                  isChanged: settings.notifyOnCrash != true,
                                  isOn: $settings.notifyOnCrash)
                UI.Form.ToggleRow(title: AppText.string("settings.general.showRevealCLI", defaultValue: "Show Reveal CLI on actions"),
                                  info: AppText.string("settings.general.showRevealCLI.info", defaultValue: "Shows the exact `container ...` command for important actions. Useful when you are learning the CLI or want to verify what will run."),
                                  isChanged: settings.revealCLI != true,
                                  isOn: $settings.revealCLI)
            }

            Section {
                UI.Form.Row(title: AppText.string("settings.general.listRefreshInterval", defaultValue: "List refresh interval"),
                            isChanged: settings.refreshInterval != 2.0) {
                    HStack(spacing: UI.Layout.Spacing.s) {
                        Slider(value: $settings.refreshInterval, in: 1...10, step: 1)
                            .frame(width: UI.Form.Width.compactSlider)
                        Text("\(Int(settings.refreshInterval))s")
                            .monospacedDigit()
                            .frame(width: UI.Form.Width.refreshReadout, alignment: .trailing)
                    }
                }
                UI.Form.Row(title: AppText.string("settings.general.keepHistoryFor", defaultValue: "Keep history for"),
                            isChanged: settings.historyRetentionDays != 7) {
                    Picker("", selection: retentionBinding) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                        .labelsHidden().fixedSize()
                }
                UI.Form.Row(title: AppText.string("settings.general.normalizeStats", defaultValue: "Normalize stats"),
                            isChanged: settings.statsNormalizationMode != .container) {
                    Picker("", selection: statsNormalizationBinding) {
                        ForEach(Core.Metrics.NormalizationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Button("Clear History…", role: .destructive) { confirmingClear = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                ConfigTransferControls()
            } header: {
                Text(AppText.string("settings.general.data", defaultValue: "Data"))
            } footer: {
                Text(AppText.string("settings.general.data.footer", defaultValue: "Live metrics use one low-priority runtime stream. The list refresh interval only controls background service, container list, and resource-cache polling. \(settings.statsNormalizationMode.footnote)"))
            }

            Section {
                UI.Form.Row(title: AppText.string("settings.general.loggingLevel", defaultValue: "Level"),
                            isChanged: settings.loggingLevel != .important) {
                    Picker("", selection: $settings.loggingLevel) {
                        ForEach(AppLogLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                LabeledContent(AppText.string("settings.logging.writeTo", defaultValue: "Write to")) {
                    ForEach(AppLogDestination.allCases) { destination in
                        Toggle(destination.displayName, isOn: setBinding(destination, in: \.enabledLogDestinations))
                            .toggleStyle(.checkbox)
                    }
                }
                VStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                    Text(AppText.string("settings.logging.categories", defaultValue: "Categories"))
                        .font(.caption)
                        .foregroundStyle(settings.enabledLogCategories.count == AppLogCategory.allCases.count ? Color.secondary : Color.blue)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)],
                              alignment: .leading,
                              spacing: UI.Layout.Spacing.s) {
                        ForEach(AppLogCategory.allCases) { category in
                            Toggle(category.displayName, isOn: setBinding(category, in: \.enabledLogCategories))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
            } header: {
                Text(AppText.string("settings.general.logging", defaultValue: "Logging"))
            } footer: {
                Text(settings.loggingLevel.footnote)
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

    private var statsNormalizationBinding: Binding<Core.Metrics.NormalizationMode> {
        Binding(get: { settings.statsNormalizationMode },
                set: { app.setStatsNormalizationMode($0) })
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
