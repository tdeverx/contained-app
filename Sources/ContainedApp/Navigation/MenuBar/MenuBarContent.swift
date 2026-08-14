import SwiftUI
import ContainedCore
import ContainedUI

/// A compact runtime center for the menu-bar extra. Deeper creation, navigation, settings, and
/// support workflows stay in the main app; this surface is intentionally status-and-action focused.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    private var runtimeDescriptors: [Core.Runtime.Descriptor] {
        let registered = app.registeredRuntimeDescriptors
        return registered.isEmpty ? app.supportedRuntimeDescriptors : registered
    }

    private var unreadActivityCount: Int {
        app.historyStore.activitySummary.unreadEvents
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
            header

            Divider()

            runtimeSection

            Divider()

            quickActions

            Divider()

            footer
        }
        .padding(UI.MenuBar.Padding.all)
        .frame(width: UI.MenuBar.Size.width)
        .background {
            UI.Theme.BackgroundLayer(material: .sheet)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: UI.Layout.Spacing.xs) {
            HStack(spacing: UI.Layout.Spacing.s) {
                Label("Contained", systemImage: app.serviceHealthy ? "shippingbox.fill" : "shippingbox")
                    .designTitleLabelStyle()
                Spacer(minLength: 0)
                UI.Badge.Status(text: runningSummary,
                                tint: app.containers.running.isEmpty ? .secondary : .green)
            }

            HStack(spacing: UI.Layout.Spacing.s) {
                UI.State.InlineStatus(overallStatus,
                                      systemImage: app.serviceHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                      tone: app.serviceHealthy ? .success : .warning)
                UI.State.StatusText(app.settings.updateChannel.displayName, style: .caption)
                Spacer(minLength: 0)
                if unreadActivityCount > 0 {
                    UI.State.InlineStatus("\(unreadActivityCount) unread",
                                          systemImage: "bell.badge",
                                          tone: .accent)
                }
            }
        }
    }

    private var runtimeSection: some View {
        VStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
            HStack {
                Text("Runtimes")
                    .designSectionLabelStyle()
                Spacer(minLength: 0)
                Text("\(runtimeDescriptors.count)")
                    .designSecondaryMonospacedDigitCaption()
            }

            runtimeCards
        }
    }

    @ViewBuilder
    private var runtimeCards: some View {
        if runtimeDescriptors.count > 2 {
            ScrollView {
                runtimeCardStack
            }
            .scrollIndicators(.hidden)
            .frame(height: UI.MenuBar.Size.runtimeListMaxHeight)
        } else {
            runtimeCardStack
        }
    }

    private var runtimeCardStack: some View {
        LazyVStack(spacing: UI.Layout.Spacing.s) {
            ForEach(runtimeDescriptors, id: \.kind) { descriptor in
                MenuBarRuntimeCard(descriptor: descriptor,
                                   openSystem: openSystem)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            UI.Action.Group([
                UI.Action.Item(systemName: "plus",
                               title: "Run",
                               help: "Run Container") {
                    activate()
                    ui.dispatch(.runContainer)
                },
                UI.Action.Item(systemName: unreadActivityCount > 0 ? "bell.badge" : "bell",
                               title: "Activity",
                               help: "Activity",
                               tint: unreadActivityCount > 0 ? .accentColor : nil) {
                    activate()
                    ui.dispatch(.activityHistory)
                },
                UI.Action.Item(systemName: "arrow.triangle.2.circlepath",
                               title: "Updates",
                               help: "Check for Updates") {
                    activate()
                    app.updater.checkForUpdates()
                }
            ])
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            Button("Open Contained") { activate() }
            Spacer(minLength: 0)
            Button("Quit") { Platform.quit() }
        }
        .buttonStyle(.borderless)
    }

    private var runningSummary: String {
        let count = app.containers.running.count
        return "\(count) running"
    }

    private var overallStatus: String {
        if runtimeDescriptors.isEmpty { return "No runtimes detected" }
        let ready = runtimeDescriptors.filter { app.runtimeIsReady($0.kind) }.count
        if ready == runtimeDescriptors.count { return "All runtimes available" }
        if ready > 0 { return "\(ready) of \(runtimeDescriptors.count) available" }
        return "Runtimes unavailable"
    }

    private func openSystem() {
        activate()
        if app.settings.usesPanelNavigation {
            ui.toggleMorph(.system)
        } else {
            ui.navigate(to: .system)
        }
    }

    private func activate() {
        Platform.activateMainWindow()
    }
}
