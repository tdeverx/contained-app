import SwiftUI
import SwiftData
import AppKit
import ContainedCore

/// The unified, **paged** creation flow. The same content drives both the toolbar's `+` morph panel
/// (where each page resizes the panel in place via `.morphPanelSize`) and the `CreationWizard` sheet
/// (fixed frame). It never opens a nested modal for the container path — selecting a box resizes and
/// advances to the next section.
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

    init(start: Start, onClose: @escaping () -> Void,
         prefill: RunSpec? = nil,
         onSoftDismissChange: (((() -> Void)?) -> Void)? = nil) {
        self.start = start
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
            ContainerConfigureView(mode: .new(prefill: spec),
                                   leading: .back { go(.chooser) },
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
        pageScaffold(title: "New network", subtitle: nil, leading: resourceLeading) {
            Form {
                TextField("Name", text: $networkName, prompt: Text("my-network"))
                TextField("Subnet", text: $networkSubnet, prompt: Text("optional, e.g. 10.0.0.0/24"))
                Toggle("Host-only (internal)", isOn: $networkInternalOnly)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                submitBar(canSubmit: !networkName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    createNetwork()
                }
            }
        }
    }

    private var volumePage: some View {
        pageScaffold(title: "New volume", subtitle: nil, leading: resourceLeading) {
            Form {
                TextField("Name", text: $volumeName, prompt: Text("my-volume"))
                TextField("Size", text: $volumeSize, prompt: Text("optional, e.g. 10G"))
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                submitBar(canSubmit: !volumeName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    createVolume()
                }
            }
        }
    }

    private var buildPage: some View {
        pageScaffold(title: "Build an image", subtitle: "From a Dockerfile + build context",
                     leading: resourceLeading) {
            BuildWorkspaceView()
        }
    }

    private var searchPage: some View {
        pageScaffold(title: "Search for an image", subtitle: "Pick one to configure and run",
                     leading: .back { go(.chooser) }) {
            RegistryImageSearch { picked in
                spec = picked
                go(.configure)
            }
        }
    }

    private var localImagesPage: some View {
        pageScaffold(title: "Choose a local image", subtitle: "Use an image already pulled",
                     leading: .back { go(.chooser) }) {
            VStack(spacing: Tokens.Space.m) {
                HStack(spacing: Tokens.Space.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Filter local images", text: $localImageQuery)
                        .textFieldStyle(.plain)
                    if !localImageQuery.isEmpty {
                        Button { localImageQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Tokens.Space.m)
                .padding(.vertical, Tokens.Space.s)
                .glassSurface(.thin, cornerRadius: Tokens.Radius.control)

                if filteredLocalImages.isEmpty {
                    ContentUnavailableView {
                        Label("No matching images", systemImage: "square.stack.3d.up")
                    } description: {
                        Text(localImageQuery.isEmpty ? "Pull or build an image first." : "Try a different filter.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Tokens.Space.xs) {
                            ForEach(filteredLocalImages) { image in
                                Button {
                                    spec = RecommendedImage.spec(for: image.reference)
                                    go(.configure)
                                } label: {
                                    localImageRow(image)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .task { await app.refreshImagesIfStale(force: true) }
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
        pageScaffold(title: "Paste Compose", subtitle: "Services with images become prefilled containers",
                     leading: .back { go(.compose) }) {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                TextEditor(text: $composeText)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(Tokens.Space.s)
                    .glassSurface(.thin, cornerRadius: Tokens.Radius.control)
                    .frame(minHeight: 260)

                HStack {
                    Spacer()
                    Button {
                        importPastedCompose()
                    } label: {
                        Label("Import", systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var imageArchivePage: some View {
        pageScaffold(title: "Load Image Archive", subtitle: "Import an OCI image .tar into the local store",
                     leading: .back { go(.chooser) }) {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                ContentUnavailableView {
                    Label("Choose an image archive", systemImage: "archivebox")
                } description: {
                    Text("After loading, choose Local image to configure and run it.")
                } actions: {
                    Button {
                        selectImageArchive()
                    } label: {
                        Label("Select File", systemImage: "folder")
                    }
                    .buttonStyle(.glassProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var templatesPage: some View {
        pageScaffold(title: "Use a saved template", subtitle: nil, leading: .back { go(.chooser) }) {
            ScrollView {
                LazyVStack(spacing: Tokens.Space.s) {
                    ForEach(saved) { template in
                        Button {
                            if let s = template.spec { spec = s; go(.configure) }
                        } label: {
                            HStack(spacing: Tokens.Space.m) {
                                Image(systemName: "bookmark.fill").foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(template.name).font(.callout.weight(.medium)).lineLimit(1)
                                    Text(Format.shortImage(template.spec?.image ?? "—"))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(Tokens.Space.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .glassSurface(.ultraThin, cornerRadius: Tokens.Radius.control)
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    private func pageScaffold<C: View>(title: String, subtitle: String?, leading: Leading,
                                       @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.s) {
                switch leading {
                case .close:
                    GlassCircleButton(systemName: "xmark", help: "Cancel", isCancel: true) { onClose() }
                case .back(let action):
                    GlassCircleButton(systemName: "chevron.left", help: "Back", action: action)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
            }
            .padding(Tokens.Space.l)
            Divider()
            content()
                .padding(Tokens.Space.l)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private func submitBar(canSubmit: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            if working { ProgressView().controlSize(.small) }
            Button {
                action()
            } label: {
                Label("Create", systemImage: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .disabled(!canSubmit || working)
        }
        .padding(Tokens.Space.l)
        .background(.clear)
    }

    private var filteredLocalImages: [ContainedCore.ImageResource] {
        let images = app.images
            .filter { $0.variants.contains(where: \.isRunnable) || $0.variants.isEmpty }
            .sorted { $0.reference.localizedCaseInsensitiveCompare($1.reference) == .orderedAscending }
        let q = localImageQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return images }
        return images.filter { $0.reference.localizedCaseInsensitiveContains(q) }
    }

    private func localImageRow(_ image: ContainedCore.ImageResource) -> some View {
        let runnable = image.variants.filter(\.isRunnable)
        let size = runnable.compactMap(\.size).max() ?? image.variants.compactMap(\.size).max()
        let arches = runnable.map(\.platform.architecture).joined(separator: ", ")
        let subtitle = [size.map { Format.bytes(UInt64($0)) }, arches.isEmpty ? nil : arches]
            .compactMap { $0 }.joined(separator: "  ·  ")

        return HStack(spacing: Tokens.Space.s) {
            Image(systemName: "square.stack.3d.up")
                .font(.callout)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(Format.shortImage(image.reference)).font(.callout.weight(.medium)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassSurface(.ultraThin, cornerRadius: Tokens.Radius.control)
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
        case .menu:      return CGSize(width: 760, height: optionPageHeight)
        case .chooser:   return CGSize(width: 640, height: twoRowOptionPageHeight)
        case .search:    return CGSize(width: 560, height: 540)
        case .localImages: return CGSize(width: 560, height: 520)
        case .compose:   return CGSize(width: 440, height: optionPageHeight)
        case .pasteCompose: return CGSize(width: 560, height: 520)
        case .imageArchive: return CGSize(width: 500, height: 360)
        case .templates: return CGSize(width: 520, height: 470)
        case .network:   return Tokens.SheetSize.small
        case .volume:    return Tokens.SheetSize.small
        case .build:     return CGSize(width: 640, height: 680)
        case .configure: return Tokens.SheetSize.form
        }
    }

    private func placement(for page: Page) -> MorphPanelPlacement {
        switch page {
        case .menu, .chooser, .compose:
            return .anchored
        case .search, .localImages, .pasteCompose, .imageArchive, .templates, .network, .volume, .build, .configure:
            return .centered
        }
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
