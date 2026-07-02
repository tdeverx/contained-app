import SwiftUI
import ContainedDesignSystem
import ContainedCore

/// Edits local card personalization for containers, images, image groups, tags, and volumes.
/// Styles stay in `PersonalizationStore`; they are never written back to runtime labels.
struct CustomizeSheet: View {
    enum Presentation {
        case sheet
        case popover
    }

    enum Target: Identifiable, Hashable {
        case container(ContainerSnapshot)
        case image(reference: String)
        case imageGroup(id: String, reference: String)
        case imageTag(reference: String, groupID: String?)
        case volume(name: String)

        var id: String {
            switch self {
            case .container(let snapshot): return "container:\(snapshot.id)"
            case .image(let reference): return "image:\(reference)"
            case .imageGroup(let id, _): return "image-group:\(id)"
            case .imageTag(let reference, let groupID): return "image-tag:\(groupID ?? "none"):\(reference)"
            case .volume(let name): return "volume:\(name)"
            }
        }

        var image: String {
            switch self {
            case .container(let snapshot): return snapshot.image
            case .image(let reference): return reference
            case .imageGroup(_, let reference): return reference
            case .imageTag(let reference, _): return reference
            case .volume(let name): return name
            }
        }

        var isImage: Bool {
            switch self {
            case .image, .imageGroup, .imageTag: return true
            case .container, .volume: return false
            }
        }

        var supportsInheritance: Bool {
            switch self {
            case .container, .image, .imageGroup, .imageTag: return true
            case .volume: return false
            }
        }

        var previewSnapshot: ContainerSnapshot {
            switch self {
            case .container(let snapshot): return snapshot
            case .image(let reference), .imageGroup(_, let reference), .imageTag(let reference, _):
                return .placeholder(id: Format.shortImage(reference), image: reference)
            case .volume(let name):
                return .placeholder(id: name, image: "")
            }
        }
    }

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    let target: Target
    let presentation: Presentation
    var onDraftChange: ((Personalization) -> Void)? = nil

    @State private var style: Personalization
    @State private var overridesInheritedStyle: Bool
    @State private var loaded: Bool

    init(snapshot: ContainerSnapshot, presentation: Presentation = .popover) {
        self.init(snapshot: snapshot,
                  presentation: presentation,
                  initialStyle: nil,
                  initiallyOverridesInheritedStyle: nil,
                  onDraftChange: nil)
    }

    init(snapshot: ContainerSnapshot,
         presentation: Presentation = .popover,
         initialStyle: Personalization? = nil,
         initiallyOverridesInheritedStyle: Bool? = nil,
         onDraftChange: ((Personalization) -> Void)? = nil) {
        self.target = .container(snapshot)
        self.presentation = presentation
        self.onDraftChange = onDraftChange
        self._style = State(initialValue: initialStyle ?? Personalization())
        self._overridesInheritedStyle = State(initialValue: initiallyOverridesInheritedStyle ?? true)
        self._loaded = State(initialValue: initialStyle != nil && initiallyOverridesInheritedStyle != nil)
    }

    init(target: Target,
         presentation: Presentation = .sheet,
         initialStyle: Personalization? = nil,
         initiallyOverridesInheritedStyle: Bool? = nil) {
        self.target = target
        self.presentation = presentation
        self._style = State(initialValue: initialStyle ?? Personalization())
        self._overridesInheritedStyle = State(initialValue: initiallyOverridesInheritedStyle ?? true)
        self._loaded = State(initialValue: initialStyle != nil
                                  && (!target.supportsInheritance || initiallyOverridesInheritedStyle != nil))
    }

    private var isPopoverPresentation: Bool { presentation == .popover }
    private var panelSize: CGSize {
        isPopoverPresentation ? CGSize(width: 430, height: 460) : CGSize(width: 480, height: 600)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: DesignTokens.Space.l) {
                    if target.supportsInheritance { inheritanceSection }
                    editableSection { styleSection }
                    if case .container = target {
                        editableSection { statusSection }
                    }
                    if !target.isImage {
                        CustomizeWidgetsPanel(style: $style,
                                              graphOptions: graphOptions,
                                              settingsDisabled: settingsDisabled)
                    }
                    editableSection { backgroundSection }
                    actionsSection
                }
                .padding(.horizontal, DesignTokens.Space.l)
                .padding(.vertical, DesignTokens.Space.m)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .sheetMaterial(!isPopoverPresentation)
        .task { await loadStyleIfNeeded() }
        .onChange(of: style) { _, newValue in onDraftChange?(newValue) }
    }

    private var header: some View {
        PanelHeader(symbol: "paintbrush.pointed",
                    title: headerTitle,
                    subtitle: imageSubtitle) {
            DesignActionGroup([
                DesignAction(systemName: "checkmark", help: AppText.save) { save() },
                DesignAction(systemName: "xmark", help: AppText.close, isCancel: true) { dismiss() }
            ])
        }
    }

    private var inheritanceSection: some View {
        PanelSection(header: AppText.string("customize.inheritance", defaultValue: "Inheritance")) {
            PanelToggleRow(title: overrideToggleTitle,
                           subtitle: overrideToggleHint,
                           isOn: overrideBinding)
        }
    }

    private var styleSection: some View {
        PanelSection(header: AppText.string("customize.style", defaultValue: "Style")) {
            PanelField(label: nicknameLabel) {
                TextField("", text: $style.nickname, prompt: Text(nicknamePrompt))
                    .textFieldStyle(.roundedBorder)
            }
            PanelToggleRow(title: AppText.string("customize.customIcon", defaultValue: "Custom icon"), isOn: $style.iconEnabled)
            if style.iconEnabled {
                PanelField(label: AppText.string("customize.icon", defaultValue: "Icon")) {
                    TextField("", text: $style.icon, prompt: Text("SF Symbol, e.g. globe, bolt"))
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                PanelRow(title: AppText.string("customize.icon", defaultValue: "Icon"),
                         subtitle: AppText.string("customize.icon.defaultSubtitle", defaultValue: "Using the default icon"))
            }
            PanelRow(title: AppText.string("customize.color", defaultValue: "Color"),
                     info: AppText.string("customize.color.info", defaultValue: "App Accent follows the accent tint from Settings; other swatches pin this style.")) {
                TintSelector(selection: $style.tint) { $0.localizedDisplayName }
            }
        }
    }

    private var statusSection: some View {
        PanelSection(header: AppText.string("customize.status", defaultValue: "Status")) {
            PanelToggleRow(title: AppText.string("customize.showStatusIndicator", defaultValue: "Show status indicator"), isOn: $style.showStatusIndicator)
            if style.showStatusIndicator {
                PanelToggleRow(title: AppText.string("customize.widget.showIcon", defaultValue: "Show icon"), isOn: $style.showStatusIcon)
                PanelToggleRow(title: AppText.string("customize.widget.showText", defaultValue: "Show text"), isOn: $style.showStatusText)
            }
        }
    }

    private var backgroundSection: some View {
        PanelSection(header: AppText.string("customize.background", defaultValue: "Background")) {
            PanelToggleRow(title: AppText.string("customize.colorCardBackground", defaultValue: "Color the card background"), isOn: $style.fillBackground)
            if style.fillBackground {
                PanelRow(title: AppText.string("customize.opacity", defaultValue: "Opacity")) {
                    HStack(spacing: DesignTokens.Space.s) {
                        Slider(value: $style.backgroundOpacity, in: 0.05...0.6)
                        Text(Format.percent(style.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: DesignTokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: AppText.string("customize.gradient", defaultValue: "Gradient"), isOn: $style.gradient)
                if style.gradient {
                    GradientAngleControl(angle: $style.gradientAngle, title: AppText.direction)
                }
                PanelRow(title: AppText.string("customize.blendMode", defaultValue: "Blend mode")) {
                    Picker("", selection: $style.backgroundBlendMode) {
                        ForEach(ColorLayerBlendMode.allCases) { mode in
                            Text(mode.localizedDisplayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    private var actionsSection: some View {
        PanelSection {
            PanelRow(title: target.isImage
                         ? AppText.string("customize.resetImageStyle", defaultValue: "Reset image style")
                         : AppText.string("customize.reset", defaultValue: "Reset"),
                     subtitle: canReset
                         ? AppText.string("customize.reset.subtitle", defaultValue: "Remove the saved local override.")
                         : AppText.string("customize.reset.noOverride", defaultValue: "No saved override to remove.")) {
                Button(role: .destructive) { reset() } label: {
                    Label(AppText.string("customize.reset", defaultValue: "Reset"), systemImage: "arrow.counterclockwise")
                }
                .disabled(!canReset)
            }
            if case .container = target {
                PanelRow(title: AppText.string("customize.applyToImage", defaultValue: "Apply to image"),
                         subtitle: AppText.string("customize.applyToImage.subtitle", defaultValue: "Make this container style the default for future containers from the same image.")) {
                    Button { applyToImage() } label: {
                        Label(AppText.string("customize.apply", defaultValue: "Apply"), systemImage: "square.stack.3d.up")
                    }
                    .disabled(settingsDisabled)
                }
            }
        }
    }

    private static let volumeMetrics: [GraphMetric] = [.diskRead, .diskWrite]
    private var graphOptions: [GraphMetric] {
        if case .volume = target { return Self.volumeMetrics }
        return GraphMetric.allCases
    }

    private var headerTitle: String {
        switch target {
        case .container: return AppText.string("customize.header.card", defaultValue: "Customize card")
        case .volume: return AppText.string("customize.header.volume", defaultValue: "Customize volume")
        case .image, .imageGroup, .imageTag: return AppText.string("customize.header.imageStyle", defaultValue: "Customize image style")
        }
    }

    private var overrideToggleTitle: String {
        switch target {
        case .container: return AppText.string("customize.override.imageStyle", defaultValue: "Override image style")
        case .image, .imageGroup: return AppText.string("customize.override.defaultImageDesign", defaultValue: "Override default image card design")
        case .imageTag: return AppText.string("customize.override.groupStyle", defaultValue: "Override group style")
        case .volume: return AppText.string("customize.override.style", defaultValue: "Override style")
        }
    }

    private var overrideToggleHint: String {
        switch target {
        case .container:
            return AppText.string("customize.override.containerHint", defaultValue: "Turn this on to customize only this container. Leave it off to inherit the image style.")
        case .image:
            return AppText.string("customize.override.imageHint", defaultValue: "Turn this on to style containers from this exact image. Leave it off to inherit the Settings default.")
        case .imageGroup:
            return AppText.string("customize.override.imageGroupHint", defaultValue: "Turn this on to style this image group. Leave it off to inherit the Settings default.")
        case .imageTag:
            return AppText.string("customize.override.imageTagHint", defaultValue: "Turn this on to style only this tag. Leave it off to inherit the image group's style.")
        case .volume:
            return ""
        }
    }

    private var nicknameLabel: String {
        if case .container = target { return AppText.string("customize.nickname", defaultValue: "Nickname") }
        return AppText.string("customize.displayName", defaultValue: "Display name")
    }

    private var nicknamePrompt: String {
        switch target {
        case .container: return target.previewSnapshot.id
        case .volume(let name): return name
        default: return Format.shortImage(target.image)
        }
    }

    private var imageSubtitle: String? {
        switch target {
        case .imageGroup:
            return AppText.string("customize.subtitle.imageGroupDefault", defaultValue: "Default for this local image group")
        case .imageTag:
            return AppText.string("customize.subtitle.imageTag", defaultValue: "Style for \(Format.shortImage(target.image))")
        case .image:
            return AppText.string("customize.subtitle.imageDefault", defaultValue: "Default for every container from \(Format.shortImage(target.image))")
        case .volume:
            return AppText.string("customize.subtitle.volume", defaultValue: "Style for this volume")
        case .container:
            return nil
        }
    }

    private var settingsDisabled: Bool {
        target.supportsInheritance && !overridesInheritedStyle
    }

    @ViewBuilder
    private func editableSection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .disabled(settingsDisabled)
            .opacity(settingsDisabled ? 0.48 : 1)
    }

    private var canReset: Bool {
        switch target {
        case .image(let reference), .imageTag(let reference, _):
            return app.personalization.imageDefault(for: reference) != nil
        case .imageGroup(let id, _):
            return app.personalization.imageGroupDefault(for: id) != nil
        case .container(let snapshot):
            return app.personalization.hasOverride(id: snapshot.id)
        case .volume(let name):
            return app.personalization.volumeStyle(for: name) != nil
        }
    }

    private var overrideBinding: Binding<Bool> {
        Binding {
            overridesInheritedStyle
        } set: { newValue in
            overridesInheritedStyle = newValue
            switch target {
            case .container, .image, .imageGroup, .imageTag:
                style = newValue ? ownStyle() : inheritedStyle()
            case .volume:
                break
            }
        }
    }

    private func loadStyleIfNeeded() async {
        guard !loaded else { return }
        switch target {
        case .container(let snapshot):
            style = app.containerStyle(for: snapshot)
            overridesInheritedStyle = app.personalization.hasOverride(id: snapshot.id)
        case .image(let reference):
            let own = app.personalization.imageDefault(for: reference)
            overridesInheritedStyle = own != nil
            style = own ?? inheritedStyle()
        case .imageTag(let reference, _):
            let own = app.personalization.imageDefault(for: reference)
            overridesInheritedStyle = own != nil
            style = own ?? inheritedStyle()
        case .imageGroup(let id, _):
            let own = app.personalization.imageGroupDefault(for: id)
            overridesInheritedStyle = own != nil
            style = own ?? inheritedStyle()
        case .volume(let name):
            style = app.volumeStyle(for: name)
            overridesInheritedStyle = true
        }
        loaded = true
        onDraftChange?(style)
    }

    private func save() {
        switch target {
        case .image(let reference):
            if overridesInheritedStyle {
                app.personalization.setImageDefault(style, for: reference)
            } else {
                app.personalization.clearImageDefault(for: reference)
            }
        case .imageTag(let reference, _):
            if overridesInheritedStyle {
                app.personalization.setImageDefault(style, for: reference)
            } else {
                app.personalization.clearImageDefault(for: reference)
            }
        case .imageGroup(let id, _):
            if overridesInheritedStyle {
                app.personalization.setImageGroupDefault(style, for: id)
            } else {
                app.personalization.clearImageGroupDefault(for: id)
            }
        case .container(let snapshot):
            if overridesInheritedStyle {
                app.personalization.setOverride(style, for: snapshot.id)
            } else {
                app.personalization.clearOverride(id: snapshot.id)
            }
        case .volume(let name):
            app.personalization.setVolumeStyle(style, for: name)
        }
        dismiss()
    }

    private func reset() {
        switch target {
        case .image(let reference), .imageTag(let reference, _):
            app.personalization.clearImageDefault(for: reference)
        case .imageGroup(let id, _):
            app.personalization.clearImageGroupDefault(for: id)
        case .container(let snapshot):
            app.personalization.clearOverride(id: snapshot.id)
        case .volume(let name):
            app.personalization.clearVolumeStyle(for: name)
        }
        dismiss()
    }

    private func applyToImage() {
        guard case .container(let snapshot) = target else { return }
        app.personalization.setImageDefault(style, for: snapshot.image)
        app.personalization.clearOverride(id: snapshot.id)
        overridesInheritedStyle = false
        dismiss()
    }

    private func inheritedStyle() -> Personalization {
        switch target {
        case .container(let snapshot):
            return app.imageStyle(for: snapshot.image)
        case .image, .imageGroup:
            return app.defaultImageStyle
        case .imageTag(_, let groupID):
            return groupID.map { app.imageGroupStyle(forID: $0) } ?? Personalization()
        case .volume:
            return Personalization()
        }
    }

    private func ownStyle() -> Personalization {
        switch target {
        case .container(let snapshot):
            return app.personalization.hasOverride(id: snapshot.id) ? app.containerStyle(for: snapshot) : inheritedStyle()
        case .image(let reference), .imageTag(let reference, _):
            return app.personalization.imageDefault(for: reference) ?? inheritedStyle()
        case .imageGroup(let id, _):
            return app.personalization.imageGroupDefault(for: id) ?? inheritedStyle()
        case .volume:
            return inheritedStyle()
        }
    }
}
