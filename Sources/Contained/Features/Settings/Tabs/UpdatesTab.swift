import SwiftUI
import ContainedCore

// MARK: - Updates

struct UpdatesTab: View {
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
                               isOn: Binding(get: { settings.appUpdateChecksEnabled },
                                             set: {
                                                 settings.appUpdateChecksEnabled = $0
                                                 app.updater.automaticallyChecks = $0
                                             }))
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
