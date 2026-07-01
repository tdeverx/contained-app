import SwiftUI
import AppKit
import ContainedCore

/// Build an image from a Dockerfile + context, streaming the BuildKit log via
/// `container build --progress plain`.
///
/// AppKit bridge (flagged per the build rule): the folder picker uses `NSOpenPanel` — SwiftUI has
/// no native directory chooser on macOS. Only the picker touches AppKit.
struct BuildWorkspaceView: View {
    @Environment(AppModel.self) private var app

    @State private var contextDir: URL?
    @State private var dockerfile = ""
    @State private var tag = ""
    @State private var platform = ""
    @State private var noCache = false
    @State private var buildArgs: [KeyValue] = []
    @State private var building = false
    @State private var run = 0          // bump to restart the console
    private var canBuild: Bool { contextDir != nil && !tag.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            if building, let context = contextDir, let client = app.client {
                StreamConsole(stream: {
                    client.streamBuild(context: context.path,
                                       tag: tag.trimmingCharacters(in: .whitespaces),
                                       dockerfile: dockerfile.isEmpty ? nil : dockerfile,
                                       buildArgs: argsDict, noCache: noCache,
                                       platform: platform.isEmpty ? nil : platform)
                }, onComplete: { ok in if ok { Task { await app.refreshImagesIfStale(force: true) } } })
                .id(run)
                .padding(Tokens.Space.s)
            } else {
                ContentUnavailableView {
                    Label("Build an image", systemImage: "hammer")
                } description: {
                    Text("Choose a context folder and a tag, then Build. Output streams here.")
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.l) {
                sourceSection
                optionsSection
                commandSection
            }
            .padding(Tokens.Space.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .frame(maxHeight: 420)
    }

    private var sourceSection: some View {
        PanelSection(header: "Source") {
            PanelField(label: "Context",
                       info: "The build context: the folder sent to the builder, usually your project root.") {
                HStack {
                    Text(contextDir?.path ?? "Choose a folder...")
                        .foregroundStyle(contextDir == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    GlassButton(singleItem: true) {
                        GlassButtonItem(help: "Choose context folder", action: chooseFolder) {
                            Label("Choose", systemImage: "folder")
                        }
                    }
                }
            }
            PanelField(label: "Dockerfile",
                       info: "Path to the Dockerfile (-f). Relative to the context if not absolute.") {
                TextField("", text: $dockerfile, prompt: Text("optional, defaults to <context>/Dockerfile"))
                    .textFieldStyle(.roundedBorder)
            }
            PanelField(label: "Tag",
                       info: "The resulting image reference (-t).") {
                TextField("", text: $tag, prompt: Text("name for the built image, e.g. myapp:latest"))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var optionsSection: some View {
        PanelSection(header: "Options") {
            PanelField(label: "Platform") {
                TextField("", text: $platform, prompt: Text("optional, e.g. linux/arm64"))
                    .textFieldStyle(.roundedBorder)
            }
            PanelToggleRow(title: "No cache",
                           info: "Build every layer from scratch (--no-cache).",
                           isOn: $noCache)
            ForEach($buildArgs) { $arg in
                PanelField(label: "Build arg") {
                    HStack {
                        TextField("KEY", text: $arg.key)
                            .textFieldStyle(.roundedBorder)
                        Text("=").foregroundStyle(.secondary)
                        TextField("value", text: $arg.value)
                            .textFieldStyle(.roundedBorder)
                        GlassButton(singleItem: true) {
                            GlassButtonItem(systemName: "minus.circle.fill",
                                            help: "Remove build argument") {
                                buildArgs.removeAll { $0.id == arg.id }
                            }
                        }
                    }
                }
            }
            PanelRow(title: "Build arguments",
                     subtitle: buildArgs.isEmpty ? "No build-time variables added." : "\(buildArgs.count) argument(s)") {
                GlassButton(singleItem: true) {
                    GlassButtonItem(help: "Add build argument", action: { buildArgs.append(KeyValue()) }) {
                        Label("Add build arg", systemImage: "plus.circle")
                    }
                }
            }
        }
    }

    private var commandSection: some View {
        PanelSection {
            HStack(spacing: Tokens.Space.s) {
                CommandPreviewBar(command: previewCommand)
                    .frame(maxWidth: .infinity)
                if building {
                    GlassButton(singleItem: true) {
                        GlassButtonItem(role: .destructive, help: "Cancel build", action: { building = false }) {
                            Label("Cancel", systemImage: "xmark")
                        }
                    }
                } else {
                    GlassButton(singleItem: true) {
                        GlassButtonItem(help: "Build image", action: startBuild) {
                            Label("Build", systemImage: "hammer.fill")
                        }
                    }
                    .disabled(!canBuild)
                }
            }
        }
    }

    private var argsDict: [String: String] {
        Dictionary(buildArgs.filter(\.isValid).map { ($0.key, $0.value) }, uniquingKeysWith: { _, b in b })
    }

    private var previewCommand: [String] {
        ContainerCommands.build(context: contextDir?.path ?? "<context>",
                                tag: tag.isEmpty ? nil : tag,
                                dockerfile: dockerfile.isEmpty ? nil : dockerfile,
                                buildArgs: argsDict, noCache: noCache,
                                platform: platform.isEmpty ? nil : platform)
    }

    private func startBuild() {
        run += 1
        building = true
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the build context folder"
        if panel.runModal() == .OK { contextDir = panel.url }
    }
}
