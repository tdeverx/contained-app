import SwiftUI
import ContainedDesignSystem
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
        LazyVStack(spacing: 0) {
            form
            Divider()
            if building, let context = contextDir, let client = app.client {
                StreamConsole(stream: {
                    client.streamBuild(context: context.path,
                                       tag: tag.trimmingCharacters(in: .whitespaces),
                                       dockerfile: dockerfile.isEmpty ? nil : dockerfile,
                                       buildArgs: argsDict, noCache: noCache,
                                       platform: platform.isEmpty ? nil : platform)
                },
                workingLabel: AppText.working,
                completedLabel: AppText.completed,
                lineCountLabel: AppText.lineCount,
                copyLogHelp: AppText.copyLog,
                failureLabel: AppErrorPresentation.message,
                onComplete: { ok in if ok { Task { await app.refreshImagesIfStale(force: true) } } })
                .id(run)
                .padding(DesignTokens.Space.s)
            } else {
                ContentUnavailableView {
                    Label(AppText.string("build.empty.title", defaultValue: "Build an image"), systemImage: "hammer")
                } description: {
                    Text(AppText.string("build.empty.description", defaultValue: "Choose a context folder and a tag, then Build. Output streams here."))
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Space.l) {
                sourceSection
                optionsSection
                commandSection
            }
            .padding(DesignTokens.Space.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .frame(maxHeight: 420)
    }

    private var sourceSection: some View {
        PanelSection(header: AppText.string("build.source", defaultValue: "Source")) {
            PanelField(label: AppText.string("build.context", defaultValue: "Context"),
                       info: AppText.string("build.context.info", defaultValue: "The build context: the folder sent to the builder, usually your project root.")) {
                HStack {
                    Text(contextDir?.path ?? AppText.string("build.chooseFolderPlaceholder", defaultValue: "Choose a folder..."))
                        .foregroundStyle(contextDir == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    DesignActionGroup(DesignAction(systemName: "folder",
                                                   title: AppText.choose,
                                                   help: AppText.chooseContextFolder,
                                                   action: chooseFolder))
                }
            }
            PanelField(label: AppText.string("build.dockerfile", defaultValue: "Dockerfile"),
                       info: AppText.string("build.dockerfile.info", defaultValue: "Path to the Dockerfile (-f). Relative to the context if not absolute.")) {
                TextField("", text: $dockerfile, prompt: Text("optional, defaults to <context>/Dockerfile"))
                    .textFieldStyle(.roundedBorder)
            }
            PanelField(label: AppText.string("build.tag", defaultValue: "Tag"),
                       info: AppText.string("build.tag.info", defaultValue: "The resulting image reference (-t).")) {
                TextField("", text: $tag, prompt: Text("name for the built image, e.g. myapp:latest"))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var optionsSection: some View {
        PanelSection(header: AppText.string("build.options", defaultValue: "Options")) {
            PanelField(label: AppText.string("build.platform", defaultValue: "Platform")) {
                TextField("", text: $platform, prompt: Text("optional, e.g. linux/arm64"))
                    .textFieldStyle(.roundedBorder)
            }
            PanelToggleRow(title: AppText.string("build.noCache", defaultValue: "No cache"),
                           info: AppText.string("build.noCache.info", defaultValue: "Build every layer from scratch (--no-cache)."),
                           isOn: $noCache)
            ForEach($buildArgs) { $arg in
                PanelField(label: AppText.string("build.arg", defaultValue: "Build arg")) {
                    HStack {
                        TextField("KEY", text: $arg.key)
                            .textFieldStyle(.roundedBorder)
                        Text("=").foregroundStyle(.secondary)
                        TextField("value", text: $arg.value)
                            .textFieldStyle(.roundedBorder)
                        DesignActionGroup(DesignAction(systemName: "minus.circle.fill",
                                                       help: AppText.removeBuildArgument) {
                                buildArgs.removeAll { $0.id == arg.id }
                        })
                    }
                }
            }
            PanelRow(title: AppText.string("build.arguments", defaultValue: "Build arguments"),
                     subtitle: buildArgs.isEmpty
                         ? AppText.string("build.arguments.empty", defaultValue: "No build-time variables added.")
                         : AppText.string("build.arguments.count", defaultValue: "\(buildArgs.count) argument(s)")) {
                DesignActionGroup(DesignAction(systemName: "plus.circle",
                                               title: AppText.string("build.addBuildArg.short", defaultValue: "Add build arg"),
                                               help: AppText.addBuildArgument) {
                    buildArgs.append(KeyValue())
                })
            }
        }
    }

    private var commandSection: some View {
        PanelSection {
            HStack(spacing: DesignTokens.Space.s) {
                CommandPreviewBar(command: previewCommand,
                                  copyHelp: AppText.copyCommand,
                                  copiedAccessibilityLabel: AppText.copied)
                    .frame(maxWidth: .infinity)
                if building {
                    DesignActionGroup(DesignAction(systemName: "xmark",
                                                   title: AppText.cancel,
                                                   help: AppText.cancelBuild,
                                                   role: .destructive) {
                        building = false
                    })
                } else {
                    DesignActionGroup(DesignAction(systemName: "hammer.fill",
                                                   title: AppText.string("build.build", defaultValue: "Build"),
                                                   help: AppText.buildImage,
                                                   isEnabled: canBuild,
                                                   action: startBuild))
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
        panel.prompt = AppText.choose
        panel.message = AppText.chooseBuildContextFolder
        if panel.runModal() == .OK { contextDir = panel.url }
    }
}
