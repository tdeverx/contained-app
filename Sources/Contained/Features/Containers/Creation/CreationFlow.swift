import SwiftUI
import SwiftData
import AppKit
import ContainedCore

/// The unified, **paged** creation flow hosted by the toolbar's `+` morph panel, where each page
/// resizes the panel in place via `.morphPanelSize`. It never opens a nested modal for the container
/// path — selecting a box resizes and advances to the next section.
///
/// Pages: `menu` (Container / Network / Volume — toolbar only) → `chooser` (Search / Local image /
/// Compose / Image archive / Templates / Skip) → `search` | `localImages` | `compose` |
/// `pasteCompose` | `imageArchive` | `templates` | `network` | `volume` → `configure` (the shared
/// `ContainerConfigureView`).
struct CreationFlow: View {
    /// Where the flow starts: the toolbar `+` begins at `menu`; other entry points begin at `chooser`.
    enum Start {
        case menu, chooser, search, configure, network, volume, build

        init(_ entry: UIState.CreationEntry) {
            switch entry {
            case .menu: self = .menu
            case .chooser: self = .chooser
            case .search: self = .search
            case .configure: self = .configure
            case .network: self = .network
            case .volume: self = .volume
            case .build: self = .build
            }
        }
    }

    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Query(sort: \Template.createdAt, order: .reverse) private var saved: [Template]

    let start: Start
    let editSnapshot: ContainerSnapshot?
    /// Close the host (dismiss the sheet / collapse the morph panel).
    var onClose: () -> Void
    var onSoftDismissChange: (((() -> Void)?) -> Void)?

    enum Page: Hashable {
        case menu, chooser, search, localImages, compose, pasteCompose, imageArchive, templates
        case network, volume, build, configure
    }
    @State private var page: Page
    @State private var spec = RunSpec()
    @State private var localImageQuery = ""
    @State private var composeText = ""
    @State private var volumeName = ""
    @State private var volumeSize = ""
    @State private var networkName = ""
    @State private var networkSubnet = ""
    @State private var networkInternalOnly = false
    @State private var working = false
    @Namespace private var tileNamespace

    private var springAnim: Animation { .spring(response: 0.42, dampingFraction: 0.86) }
    private var optionPageHeight: CGFloat { GlassOptionTile.defaultHeight + (Tokens.Space.m * 2) }
    private var twoRowOptionPageHeight: CGFloat { optionPageHeight + GlassOptionTile.defaultHeight + Tokens.Space.s }
    private var menuSize: CGSize { CGSize(width: 760, height: optionPageHeight) }
    private var chooserSize: CGSize { CGSize(width: 640, height: twoRowOptionPageHeight) }

    private enum PanelSize {
        static let search = CGSize(width: 560, height: 540)
        static let localImages = CGSize(width: 560, height: 520)
        static let composeWidth: CGFloat = 440
        static let pasteCompose = CGSize(width: 560, height: 520)
        static let imageArchive = CGSize(width: 500, height: 360)
        static let templates = CGSize(width: 520, height: 470)
        static let build = CGSize(width: 640, height: 680)
    }

    init(start: Start, onClose: @escaping () -> Void,
         prefill: RunSpec? = nil,
         editSnapshot: ContainerSnapshot? = nil,
         onSoftDismissChange: (((() -> Void)?) -> Void)? = nil) {
        self.start = start
        self.editSnapshot = editSnapshot
        self.onClose = onClose
        self.onSoftDismissChange = onSoftDismissChange
        if let prefill {
            _spec = State(initialValue: prefill)
        }
        switch start {
        case .menu:    _page = State(initialValue: .menu)
        case .chooser: _page = State(initialValue: .chooser)
        case .search:  _page = State(initialValue: .search)
        case .configure: _page = State(initialValue: .configure)
        case .network: _page = State(initialValue: .network)
        case .volume:  _page = State(initialValue: .volume)
        case .build:   _page = State(initialValue: .build)
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .morphPanelSize(size(for: page))
            .morphPanelPlacement(placement(for: page))
            .animation(springAnim, value: page)
            .onAppear { publishSoftDismiss() }
            .onDisappear { onSoftDismissChange?(nil) }
            .onChange(of: page) { _, _ in publishSoftDismiss() }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .menu:      menuPage
        case .chooser:   chooserPage
        case .search:    searchPage
        case .localImages: localImagesPage
        case .compose:   composePage
        case .pasteCompose: pasteComposePage
        case .imageArchive: imageArchivePage
        case .templates: templatesPage
        case .network:   networkPage
        case .volume:    volumePage
        case .build:     buildPage
        case .configure:
            ContainerConfigureView(mode: configureMode,
                                   leading: configureLeading,
                                   onFinished: onClose)
        }
    }

    // MARK: Pages

    private var menuPage: some View {
        gridScaffold {
            optionStack {
                optionRow {
                    box(symbol: "shippingbox", title: "Container",
                        subtitle: "Configure and run an image",
                        matchedID: "creation-option-0") { go(.chooser) }
                    box(symbol: "hammer", title: "Build",
                        subtitle: "Build an image from a Dockerfile",
                        matchedID: "creation-option-1") { go(.build) }
                    box(symbol: "network", title: "Network",
                        subtitle: "Create a container network",
                        matchedID: "creation-option-2") { go(.network) }
                    box(symbol: "externaldrive", title: "Volume",
                        subtitle: "Create persistent storage",
                        matchedID: "creation-option-3") { go(.volume) }
                }
            }
        }
    }

    private var chooserPage: some View {
        gridScaffold {
            optionStack {
                optionRow {
                    box(symbol: "magnifyingglass", title: "Search",
                        subtitle: "Find an image on Docker Hub",
                        matchedID: "creation-option-0") { go(.search) }
                    box(symbol: "square.stack.3d.up", title: "Local image",
                        subtitle: app.images.isEmpty ? "Choose from pulled images" : "Use an image already pulled",
                        matchedID: "creation-option-1") {
                        go(.localImages)
                    }
                    box(symbol: "slider.horizontal.3", title: "Start from scratch",
                        subtitle: "Configure manually",
                        matchedID: "creation-option-2") { spec = RunSpec(); go(.configure) }
                }
                optionRow {
                    box(symbol: "shippingbox.and.arrow.backward", title: "Compose",
                        subtitle: "Paste YAML or choose a file",
                        matchedID: "compose-option-0") { go(.compose) }
                    box(symbol: "archivebox", title: "Image archive",
                        subtitle: "Load an image .tar") { go(.imageArchive) }
                    box(symbol: "bookmark.fill", title: "Templates",
                        subtitle: saved.isEmpty ? "None saved yet" : "Reuse a saved recipe",
                        enabled: !saved.isEmpty) { go(.templates) }
                }
            }
        }
    }

    private var networkPage: some View {
        pageScaffold(symbol: "network", title: "New network", subtitle: nil,
                     leading: resourceLeading, contentAlignment: .top) {
            CreationNetworkFields(name: $networkName,
                                  subnet: $networkSubnet,
                                  internalOnly: $networkInternalOnly,
                                  working: working,
                                  onSubmit: createNetwork)
        }
    }

    private var volumePage: some View {
        pageScaffold(symbol: "externaldrive", title: "New volume", subtitle: nil,
                     leading: resourceLeading, contentAlignment: .top) {
            CreationVolumeFields(name: $volumeName,
                                 size: $volumeSize,
                                 working: working,
                                 onSubmit: createVolume)
        }
    }

    private var buildPage: some View {
        pageScaffold(symbol: "hammer", title: "Build an image", subtitle: "From a Dockerfile + build context",
                     leading: resourceLeading) {
            BuildWorkspaceView()
        }
    }

    private var searchPage: some View {
        pageScaffold(symbol: "magnifyingglass", title: "Search for an image", subtitle: "Pick one to configure and run",
                     leading: .back { go(.chooser) }) {
            RegistryImageSearch { picked in
                spec = picked
                go(.configure)
            }
        }
    }

    private var localImagesPage: some View {
        pageScaffold(symbol: "square.stack.3d.up", title: "Choose a local image", subtitle: "Use an image already pulled",
                     leading: .back { go(.chooser) }) {
            CreationLocalImagesContent(query: $localImageQuery) { picked in
                spec = picked
                go(.configure)
            }
        }
    }

    private var composePage: some View {
        gridScaffold {
            optionStack {
                optionRow {
                    box(symbol: "doc.plaintext", title: "Paste YAML",
                        subtitle: "Paste compose content",
                        matchedID: "compose-option-0") { go(.pasteCompose) }
                    box(symbol: "folder", title: "Select file",
                        subtitle: "Choose compose.yaml",
                        matchedID: "compose-option-1") { selectComposeFile() }
                }
            }
        }
    }

    private var pasteComposePage: some View {
        pageScaffold(symbol: "doc.plaintext", title: "Paste Compose", subtitle: "Services with images become prefilled containers",
                     leading: .back { go(.compose) }) {
            CreationPastedComposeContent(text: $composeText, onImport: importPastedCompose)
        }
    }

    private var imageArchivePage: some View {
        pageScaffold(symbol: "archivebox", title: "Load Image Archive", subtitle: "Import an OCI image .tar into the local store",
                     leading: .back { go(.chooser) }) {
            CreationImageArchiveContent(onSelect: selectImageArchive)
        }
    }

    private var templatesPage: some View {
        pageScaffold(symbol: "bookmark.fill", title: "Use a saved template", subtitle: nil,
                     leading: .back { go(.chooser) }) {
            CreationTemplatesContent(templates: saved) { selected in
                spec = selected
                go(.configure)
            }
        }
    }

    // MARK: Scaffolding

    private enum Leading {
        case close
        case back(() -> Void)
    }

    private var resourceLeading: Leading {
        start == .menu ? .back { go(.menu) } : .close
    }

    private var configureMode: ContainerEditSheet.Mode {
        if let editSnapshot {
            return .edit(editSnapshot, onComplete: {})
        }
        return .new(prefill: spec)
    }

    private var configureLeading: ContainerConfigureView.Leading {
        if editSnapshot != nil { return .back { onClose() } }
        return .back { go(.chooser) }
    }

    private func pageScaffold<C: View>(symbol: String,
                                       title: String,
                                       subtitle: String?,
                                       leading: Leading,
                                       contentAlignment: Alignment = .topLeading,
                                       @ViewBuilder content: @escaping () -> C) -> some View {
        // These pages own their own scrolling (search results, build workspace, template lists), so the
        // scaffold runs in non-scrolling mode — unified chrome without nesting scroll views. Size is set
        // by `CreationFlow.body`'s `morphPanelSize(size(for:))`.
        MorphPanelScaffold(width: 0, scrolls: false) {
            VStack(spacing: 0) {
                PanelHeader(symbol: symbol, title: title, subtitle: subtitle) {
                    GlassButton(singleItem: true) {
                        leadingControl(leading)
                    }
                }
                Divider()
            }
        } content: {
            content()
                .padding(Tokens.Space.s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        }
    }

    @ViewBuilder
    private func leadingControl(_ leading: Leading) -> some View {
        switch leading {
        case .close:
            GlassButtonItem(systemName: "xmark", help: "Cancel", isCancel: true) { onClose() }
        case .back(let action):
            GlassButtonItem(systemName: "chevron.left", help: "Back", action: action)
        }
    }

    private func gridScaffold<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(Tokens.Space.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func optionStack<C: View>(@ViewBuilder content: () -> C) -> some View {
        GlassEffectContainer(spacing: Tokens.Space.s) {
            VStack(spacing: Tokens.Space.s) { content() }
        }
    }

    private func optionRow<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(spacing: Tokens.Space.s) { content() }
    }

    private func box(symbol: String, title: String, subtitle: String? = nil,
                     matchedID: String? = nil,
                     enabled: Bool = true, action: @escaping () -> Void) -> some View {
        GlassOptionTile(symbol: symbol, title: title, subtitle: subtitle,
                        enabled: enabled,
                        matchedID: matchedID,
                        matchedNamespace: matchedID == nil ? nil : tileNamespace,
                        action: action)
    }

    // MARK: Navigation + actions

    private func go(_ next: Page) {
        withAnimation(springAnim) { page = next }
    }

    private func publishSoftDismiss() {
        onSoftDismissChange?(page == .menu && start == .menu ? nil : { softDismiss() })
    }

    private func softDismiss() {
        switch page {
        case .menu:
            onClose()
        case .chooser, .network, .volume, .build:
            switch start {
            case .menu: go(.menu)
            default: onClose()
            }
        case .compose:
            go(.chooser)
        case .pasteCompose:
            go(.compose)
        case .search, .localImages, .imageArchive, .templates, .configure:
            go(.chooser)
        }
    }

    private func size(for page: Page) -> CGSize {
        switch page {
        case .menu:      return menuSize
        case .chooser:   return chooserSize
        case .search:    return PanelSize.search
        case .localImages: return PanelSize.localImages
        case .compose:   return CGSize(width: PanelSize.composeWidth, height: optionPageHeight)
        case .pasteCompose: return PanelSize.pasteCompose
        case .imageArchive: return PanelSize.imageArchive
        case .templates: return PanelSize.templates
        case .network:   return Tokens.SheetSize.small
        case .volume:    return Tokens.SheetSize.small
        case .build:     return PanelSize.build
        case .configure: return Tokens.SheetSize.form
        }
    }

    private func placement(for page: Page) -> MorphPanelPlacement {
        .anchored
    }

    /// Pick a compose file, then use the existing prefill queue (one form per service).
    private func selectComposeFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.yaml]
        panel.message = "Choose a compose.yaml"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        onClose()
        ComposeImport.importFile(at: url, app: app, ui: ui)
    }

    private func importPastedCompose() {
        let text = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onClose()
        ComposeImport.importText(text, app: app, ui: ui)
    }

    /// Pick an image tar archive and load it into the local image store.
    private func selectImageArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.message = "Choose an image .tar archive"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        onClose()
        app.loadImageTar(at: url)
    }

    private func createVolume() {
        let name = volumeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        working = true
        Task {
            let ok = await app.createVolume(
                name: name,
                size: volumeSize.trimmingCharacters(in: .whitespaces).nilIfEmpty
            )
            working = false
            if ok { onClose() }
        }
    }

    private func createNetwork() {
        let name = networkName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        working = true
        Task {
            let ok = await app.createNetwork(
                name: name,
                subnet: networkSubnet.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                internalOnly: networkInternalOnly
            )
            working = false
            if ok { onClose() }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
