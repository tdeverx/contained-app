import SwiftUI
import ContainedUI
import UniformTypeIdentifiers
import ContainedCore

/// Build an image from a Dockerfile + context, streaming the BuildKit log via
/// `container build --progress plain`.
struct BuildWorkspaceView: View {
    @Environment(AppModel.self) private var app

    @State private var contextDir: URL?
    @State private var dockerfile = ""
    @State private var tag = ""
    @State private var platform = ""
    @State private var noCache = false
    @State private var buildArgs: [KeyValue] = []
    @State private var runtimeKind = AppRuntimeIntent.placeholderKind
    @State private var building = false
    @State private var choosingContext = false
    @State private var run = 0          // bump to restart the console
    private var canBuild: Bool { contextDir != nil && !tag.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        LazyVStack(spacing: 0) {
            form
            Divider()
            if building, let context = contextDir, let client = app.client {
                UI.Console.Stream(stream: {
                    client.streamBuild(context: context.path,
                                       tag: tag.trimmingCharacters(in: .whitespaces),
                                       dockerfile: dockerfile.isEmpty ? nil : dockerfile,
                                       buildArgs: argsDict, noCache: noCache,
                                       platform: platform.isEmpty ? nil : platform,
                                       runtimeKind: runtimeKind)
                },
                workingLabel: AppText.working,
                completedLabel: AppText.completed,
                lineCountLabel: AppText.lineCount,
                copyLogHelp: AppText.copyLog,
                failureLabel: AppErrorPresentation.message,
                onComplete: { ok in if ok { Task { await app.refreshImagesIfNeeded(force: true) } } })
                .id(run)
                .padding(UI.Layout.Spacing.s)
            } else {
                UI.State.Empty(AppText.string("build.empty.title", defaultValue: "Build an image"),
                                 systemImage: "hammer",
                                 description: AppText.string("build.empty.description", defaultValue: "Choose a context folder and a tag, then Build. Output streams here."))
            }
        }
        .onAppear(perform: normalizeRuntimeSelection)
        .fileImporter(isPresented: $choosingContext,
                      allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                contextDir = url
            case .failure(let error):
                app.flash(error.appDisplayMessage)
            }
        }
    }

    private var form: some View {
        ScrollView {
            LazyVStack(spacing: UI.Layout.Spacing.l) {
                sourceSection
                optionsSection
                commandSection
            }
            .padding(UI.Layout.Spacing.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .frame(maxHeight: 420)
    }

    private var sourceSection: some View {
        UI.Panel.Section(header: AppText.string("build.source", defaultValue: "Source")) {
            CreationRuntimePickerRow(runtimeKind: $runtimeKind,
                                     runtimes: buildRuntimes,
                                     disabledReason: app.runtimePickerDisabledReason)
            UI.Panel.Field(label: AppText.string("build.context", defaultValue: "Context"),
                       info: AppText.string("build.context.info", defaultValue: "The build context: the folder sent to the builder, usually your project root.")) {
                HStack {
                    UI.State.StatusText(contextDir?.path ?? AppText.string("build.chooseFolderPlaceholder", defaultValue: "Choose a folder..."),
                                     tone: contextDir == nil ? .neutral : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    UI.Action.Group(UI.Action.Item(systemName: "folder",
                                                   title: AppText.choose,
                                                   help: AppText.chooseContextFolder,
                                                   action: chooseFolder))
                }
            }
            UI.Panel.Field(label: AppText.string("build.dockerfile", defaultValue: "Dockerfile"),
                       info: AppText.string("build.dockerfile.info", defaultValue: "Path to the Dockerfile (-f). Relative to the context if not absolute.")) {
                TextField("", text: $dockerfile, prompt: Text("optional, defaults to <context>/Dockerfile"))
                    .textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("build.tag", defaultValue: "Tag"),
                       info: AppText.string("build.tag.info", defaultValue: "The resulting image reference (-t).")) {
                TextField("", text: $tag, prompt: Text("name for the built image, e.g. myapp:latest"))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var optionsSection: some View {
        UI.Panel.Section(header: AppText.string("build.options", defaultValue: "Options")) {
            UI.Panel.Field(label: AppText.string("build.platform", defaultValue: "Platform")) {
                TextField("", text: $platform, prompt: Text("optional, e.g. linux/arm64"))
                    .textFieldStyle(.roundedBorder)
            }
            UI.Panel.ToggleRow(title: AppText.string("build.noCache", defaultValue: "No cache"),
                           info: AppText.string("build.noCache.info", defaultValue: "Build every layer from scratch (--no-cache)."),
                           isOn: $noCache)
            ForEach(buildArgs) { arg in
                UI.Panel.Field(label: AppText.string("build.arg", defaultValue: "Build arg")) {
                    HStack {
                        TextField("KEY", text: buildArgBinding(id: arg.id, \.key, fallback: ""))
                            .textFieldStyle(.roundedBorder)
                        UI.State.StatusText("=")
                        TextField("value", text: buildArgBinding(id: arg.id, \.value, fallback: ""))
                            .textFieldStyle(.roundedBorder)
                        UI.Action.Group(UI.Action.Item(systemName: "minus.circle.fill",
                                                       help: AppText.removeBuildArgument) {
                                buildArgs.removeAll { $0.id == arg.id }
                        })
                    }
                }
            }
            UI.Panel.Row(title: AppText.string("build.arguments", defaultValue: "Build arguments"),
                     subtitle: buildArgs.isEmpty
                         ? AppText.string("build.arguments.empty", defaultValue: "No build-time variables added.")
                         : AppText.string("build.arguments.count", defaultValue: "\(buildArgs.count) argument(s)")) {
                UI.Action.Group(UI.Action.Item(systemName: "plus.circle",
                                               title: AppText.string("build.addBuildArg.short", defaultValue: "Add build arg"),
                                               help: AppText.addBuildArgument) {
                    buildArgs.append(KeyValue())
                })
            }
        }
    }

    private var commandSection: some View {
        UI.Panel.Section {
            HStack(spacing: UI.Layout.Spacing.s) {
                UI.Command.PreviewBar(commandText: previewCommandText,
                                  copyHelp: AppText.copyCommand,
                                  copiedAccessibilityLabel: AppText.copied)
                    .frame(maxWidth: .infinity)
                if building {
                    UI.Action.Group(UI.Action.Item(systemName: "xmark",
                                                   title: AppText.cancel,
                                                   help: AppText.cancelBuild,
                                                   role: .destructive) {
                        building = false
                    })
                } else {
                    UI.Action.Group(UI.Action.Item(systemName: "hammer.fill",
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
        Core.Command.buildPreview(context: contextDir?.path ?? "<context>",
                                tag: tag.isEmpty ? nil : tag,
                                dockerfile: dockerfile.isEmpty ? nil : dockerfile,
                                buildArgs: argsDict, noCache: noCache,
                                platform: platform.isEmpty ? nil : platform,
                                runtimeKind: runtimeKind)
    }

    private var previewCommandText: String {
        app.commandPreviewText(arguments: previewCommand, runtimeKind: runtimeKind)
    }

    private func startBuild() {
        run += 1
        building = true
    }

    private func chooseFolder() {
        choosingContext = true
    }

    private var buildRuntimes: [Core.Runtime.Descriptor] {
        app.runtimeDescriptors(supporting: .imageBuild)
    }

    private func normalizeRuntimeSelection() {
        runtimeKind = app.preselectedRuntimeKind(current: runtimeKind, capability: .imageBuild)
    }

    private func buildArgBinding<Value>(id: KeyValue.ID,
                                        _ keyPath: WritableKeyPath<KeyValue, Value>,
                                        fallback: Value) -> Binding<Value> {
        Binding {
            buildArgs.first { $0.id == id }?[keyPath: keyPath] ?? fallback
        } set: { newValue in
            guard let index = buildArgs.firstIndex(where: { $0.id == id }) else { return }
            buildArgs[index][keyPath: keyPath] = newValue
        }
    }
}
