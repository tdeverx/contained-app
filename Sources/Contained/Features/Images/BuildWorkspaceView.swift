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
        Form {
            Section("Source") {
                LabeledContent("Context") {
                    HStack {
                        Text(contextDir?.path ?? "Choose a folder…")
                            .foregroundStyle(contextDir == nil ? .secondary : .primary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        GlassButton(singleItem: true) {
                            GlassButtonItem(help: "Choose context folder", action: chooseFolder) {
                                Label("Choose", systemImage: "folder")
                            }
                        }
                    }
                }
                .fieldInfo("The build context — the folder sent to the builder (usually your project root).")
                TextField("Dockerfile", text: $dockerfile, prompt: Text("optional — defaults to <context>/Dockerfile"))
                    .fieldInfo("Path to the Dockerfile (-f). Relative to the context if not absolute.")
                TextField("Tag", text: $tag, prompt: Text("name for the built image, e.g. myapp:latest"))
                    .fieldInfo("The resulting image reference (-t).")
            }
            Section("Options") {
                TextField("Platform", text: $platform, prompt: Text("optional, e.g. linux/arm64"))
                Toggle("No cache", isOn: $noCache)
                    .fieldInfo("Build every layer from scratch (--no-cache).")
                ForEach($buildArgs) { $arg in
                    HStack {
                        TextField("KEY", text: $arg.key)
                        Text("=").foregroundStyle(.secondary)
                        TextField("value", text: $arg.value)
                        GlassButton(singleItem: true) {
                            GlassButtonItem(systemName: "minus.circle.fill",
                                            help: "Remove build argument") {
                                buildArgs.removeAll { $0.id == arg.id }
                            }
                        }
                    }
                }
                GlassButton(singleItem: true) {
                    GlassButtonItem(help: "Add build argument", action: { buildArgs.append(KeyValue()) }) {
                        Label("Add build arg", systemImage: "plus.circle")
                    }
                }
            }
            Section {
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
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .frame(maxHeight: 420)
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
