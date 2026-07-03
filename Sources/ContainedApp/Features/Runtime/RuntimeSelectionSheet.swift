import SwiftUI
import ContainedCore
import ContainedUI

struct RuntimeSelectionSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    let request: UIState.RuntimeSelectionRequest
    @State private var runtimeKind = Core.Runtime.Kind.appleContainer

    var body: some View {
        UI.Panel.Scaffold(width: 420, scrolls: false) {
            UI.Panel.Header(symbol: request.symbol,
                            title: AppText.runtime,
                            subtitle: request.subtitle) {
                UI.Action.Group(UI.Action.Item(systemName: "xmark",
                                               help: AppText.cancel,
                                               isCancel: true) { cancel() })
            }
            Divider()
        } content: {
            VStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
                if runtimes.isEmpty {
                    UI.State.Empty(AppText.containerRuntimeNotReady,
                                   systemImage: "exclamationmark.triangle",
                                   description: AppText.string("runtime.selector.none",
                                                               defaultValue: "No compatible runtime is available."))
                } else {
                    UI.Panel.Section {
                        UI.Panel.Row(title: AppText.runtime,
                                     subtitle: request.message) {
                            Picker("", selection: $runtimeKind) {
                                ForEach(runtimes, id: \.kind) { descriptor in
                                    Text(descriptor.displayName).tag(descriptor.kind)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                HStack {
                    Spacer()
                    UI.Action.TextButton(title: AppText.cancel,
                                         systemName: "xmark",
                                         role: .cancel) { cancel() }
                    UI.Action.TextButton(title: request.actionTitle,
                                         systemName: "checkmark",
                                         prominence: .prominent,
                                         isEnabled: !runtimes.isEmpty) { run() }
                }
            }
            .padding(UI.Layout.Spacing.s)
            .frame(width: 420)
        }
        .frame(width: 420, height: 220)
        .onAppear { selectAvailableRuntimeIfNeeded() }
    }

    private var runtimes: [Core.Runtime.Descriptor] {
        app.availableRuntimeDescriptors.filter { $0.supports(request.requiredCapability) }
    }

    private func selectAvailableRuntimeIfNeeded() {
        guard let first = runtimes.first,
              !runtimes.contains(where: { $0.kind == runtimeKind }) else { return }
        runtimeKind = first.kind
    }

    private func cancel() {
        ui.runtimeSelectionRequest = nil
    }

    private func run() {
        switch request {
        case .composeFile(let url):
            ComposeImport.importFile(at: url, runtimeKind: runtimeKind, app: app, ui: ui)
        case .composeText(let text, let projectName, let baseDirectory):
            ComposeImport.importText(text,
                                     projectName: projectName,
                                     baseDirectory: baseDirectory,
                                     runtimeKind: runtimeKind,
                                     app: app,
                                     ui: ui)
        case .imageArchive(let url):
            app.loadImageTar(at: url, runtimeKind: runtimeKind)
        }
        ui.runtimeSelectionRequest = nil
    }
}

private extension UIState.RuntimeSelectionRequest {
    var requiredCapability: Core.Runtime.Capability {
        switch self {
        case .composeFile, .composeText:
            return .composeImport
        case .imageArchive:
            return .imageArchive
        }
    }

    var symbol: String {
        switch self {
        case .composeFile, .composeText:
            return "shippingbox.and.arrow.backward"
        case .imageArchive:
            return "archivebox"
        }
    }

    var subtitle: String {
        switch self {
        case .composeFile, .composeText:
            return AppText.string("runtime.selector.compose.subtitle", defaultValue: "Import Compose services")
        case .imageArchive:
            return AppText.string("runtime.selector.imageArchive.subtitle", defaultValue: "Load image archive")
        }
    }

    var message: String {
        switch self {
        case .composeFile, .composeText:
            return AppText.string("runtime.selector.compose.message",
                                  defaultValue: "Choose the runtime that should receive the imported Compose services.")
        case .imageArchive:
            return AppText.string("runtime.selector.imageArchive.message",
                                  defaultValue: "Choose the runtime that should load this image archive.")
        }
    }

    var actionTitle: String {
        switch self {
        case .composeFile, .composeText:
            return AppText.string("common.import", defaultValue: "Import")
        case .imageArchive:
            return AppText.string("common.load", defaultValue: "Load")
        }
    }
}
