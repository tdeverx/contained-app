import SwiftUI
import ContainedCore

/// Edit a card style and store it locally (PersonalizationStore) — never as labels. The same sheet
/// styles a single container (with a scope picker for per-container vs image-wide) or an image's
/// default directly (from the Images list).
struct CustomizeSheet: View {
    enum Presentation {
        case sheet
        case popover
    }

    /// What's being styled. Identifiable so it can drive `.sheet(item:)`.
    enum Target: Identifiable, Hashable {
        case container(ContainerSnapshot)
        case image(reference: String)
        case imageGroup(id: String, reference: String)
        case imageTag(reference: String, groupID: String?)
        case volume(name: String)

        var id: String {
            switch self {
            case .container(let s): return "container:\(s.id)"
            case .image(let r):     return "image:\(r)"
            case .imageGroup(let id, _): return "image-group:\(id)"
            case .imageTag(let r, let groupID): return "image-tag:\(groupID ?? "none"):\(r)"
            case .volume(let name): return "volume:\(name)"
            }
        }
        var image: String {
            switch self {
            case .container(let s): return s.image
            case .image(let r):     return r
            case .imageGroup(_, let r): return r
            case .imageTag(let r, _): return r
            case .volume(let name): return name
            }
        }
        /// True for image-scoped targets — drives the "image style" wording.
        var isImage: Bool {
            switch self {
            case .image, .imageGroup, .imageTag: return true
            case .container, .volume: return false
            }
        }
        /// Targets that inherit from a parent and so offer an override toggle: a container (inherits the
        /// image style) and an image tag (inherits its group's style). Direct targets edit in place.
        var supportsInheritance: Bool {
            switch self {
            case .container, .imageTag: return true
            case .image, .imageGroup, .volume: return false
            }
        }
        /// The group id a tag inherits from (nil for everything else).
        var tagGroupID: String? {
            if case .imageTag(_, let groupID) = self { return groupID }
            return nil
        }
        /// The snapshot the live preview renders — the real one for a container, a synthetic one for
        /// an image/volume (so we can show how cards from it will look).
        var previewSnapshot: ContainerSnapshot {
            switch self {
            case .container(let s): return s
            case .image(let r), .imageGroup(_, let r), .imageTag(let r, _):
                return .placeholder(id: Format.shortImage(r), image: r)
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

    /// Convenience initializer for the container case (keeps existing call sites working).
    init(snapshot: ContainerSnapshot, presentation: Presentation = .popover) {
        self.target = .container(snapshot)
        self.presentation = presentation
    }

    init(snapshot: ContainerSnapshot,
         presentation: Presentation = .popover,
         onDraftChange: ((Personalization) -> Void)? = nil) {
        self.target = .container(snapshot)
        self.presentation = presentation
        self.onDraftChange = onDraftChange
    }

    init(target: Target, presentation: Presentation = .sheet) {
        self.target = target
        self.presentation = presentation
    }

    @State private var style = Personalization()
    @State private var overrideContainerStyle = true
    @State private var loaded = false

    private var isPopoverPresentation: Bool { presentation == .popover }
    private var panelSize: CGSize {
        isPopoverPresentation ? CGSize(width: 430, height: 460) : CGSize(width: 480, height: 600)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: headerTitle,
                        subtitle: imageSubtitle,
                        onCancel: { dismiss() }) {
                GlassButton(singleItem: true) {
                    GlassButtonItem(systemName: "checkmark", help: "Save") { save() }
                }
            }

            Form {
                if target.supportsInheritance {
                    Section("Inheritance") {
                        Toggle(overrideToggleTitle, isOn: overrideBinding)
                            .fieldInfo(overrideToggleHint)
                    }
                }
                Section("Style") {
                    TextField(nicknameLabel,
                              text: $style.nickname,
                              prompt: Text(nicknamePrompt))
                    Toggle("Custom icon", isOn: $style.iconEnabled)
                    if style.iconEnabled {
                        TextField("Icon", text: $style.icon, prompt: Text("SF Symbol, e.g. globe, bolt"))
                    } else {
                        Text("Using the default icon")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Color") { TintSelector(selection: $style.tint) }
                        .fieldInfo("“App Accent” (the linked swatch) follows the app accent from Settings, so the card tracks your theme. Pick any other color to pin this card.")
                }
                .disabled(settingsDisabled)
                .opacity(settingsDisabled ? 0.48 : 1)

                if case .container = target {
                    Section("Status") {
                        Toggle("Show status indicator", isOn: $style.showStatusIndicator)
                        if style.showStatusIndicator {
                            Toggle("Show icon", isOn: $style.showStatusIcon)
                            Toggle("Show text", isOn: $style.showStatusText)
                        }
                    }
                    .disabled(settingsDisabled)
                    .opacity(settingsDisabled ? 0.48 : 1)
                }

                if target.isImage {
                    EmptyView()
                } else {
                    ForEach(0..<Personalization.widgetSlotCount, id: \.self) { index in
                        Section("Widget \(index + 1)") {
                            Toggle("Enabled", isOn: widgetEnabledBinding(index))
                            if widgetEnabled(index) {
                                Toggle("Show icon", isOn: widgetShowIconBinding(index))
                                Toggle("Show text", isOn: widgetShowTextBinding(index))
                                Picker("Graph Metric", selection: widgetMetricBinding(index)) {
                                    ForEach(graphOptions) {
                                        Label(graphLabel($0), systemImage: $0.systemImage).tag($0)
                                    }
                                }
                                Picker("Graph Type", selection: widgetStyleBinding(index)) {
                                    ForEach(GraphStyle.allCases) { Text($0.displayName).tag($0) }
                                }
                            }
                        }
                        .disabled(settingsDisabled)
                        .opacity(settingsDisabled ? 0.48 : 1)
                    }
                }

                Section("Background") {
                    Toggle("Color the card background", isOn: $style.fillBackground)
                    if style.fillBackground {
                        LabeledContent("Opacity") {
                            Slider(value: $style.backgroundOpacity, in: 0.05...0.6)
                            Text(Format.percent(style.backgroundOpacity))
                                .monospacedDigit()
                                .frame(width: Tokens.FormWidth.shortReadout)
                        }
                        Toggle("Gradient", isOn: $style.gradient)
                        if style.gradient { GradientAngleControl(angle: $style.gradientAngle) }
                    }
                }
                .disabled(settingsDisabled)
                .opacity(settingsDisabled ? 0.48 : 1)

                Section {
                    Button(role: .destructive) { reset() } label: {
                        Label(target.isImage ? "Reset image style" : "Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!canReset)
                    if case .container = target {
                        Button { applyToImage() } label: {
                            Label("Apply to image", systemImage: "square.stack.3d.up")
                        }
                        .disabled(settingsDisabled)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .sheetMaterial(!isPopoverPresentation)
        .task {
            guard !loaded else { return }
            switch target {
            case .container(let snapshot):
                style = app.containerStyle(for: snapshot)
                overrideContainerStyle = app.personalization.hasOverride(id: snapshot.id)
            case .image(let reference):
                style = app.personalization.imageDefault(for: reference) ?? Personalization()
                overrideContainerStyle = true
            case .imageTag(let reference, _):
                // A tag inherits its group's style unless it has its own saved default (override on).
                let own = app.personalization.imageDefault(for: reference)
                overrideContainerStyle = own != nil
                style = own ?? inheritedStyle()
            case .imageGroup(let id, _):
                style = app.personalization.imageGroupDefault(for: id) ?? Personalization()
                overrideContainerStyle = true
            case .volume(let name):
                style = app.volumeStyle(for: name)
                overrideContainerStyle = true
            }
            loaded = true
            onDraftChange?(style)
        }
        .onChange(of: style) { _, newValue in
            onDraftChange?(newValue)
        }
    }

    /// The graph metrics offered for the current target — volumes plot read/write, everything else
    /// gets the full set.
    private static let volumeMetrics: [GraphMetric] = [.diskRead, .diskWrite]
    private var graphOptions: [GraphMetric] {
        if case .volume = target { return Self.volumeMetrics }
        return GraphMetric.allCases
    }
    private func graphLabel(_ metric: GraphMetric) -> String {
        if case .volume = target {
            switch metric {
            case .diskRead: return "Read"
            case .diskWrite: return "Write"
            default: return metric.displayName
            }
        }
        return metric.displayName
    }

    private var headerTitle: String {
        switch target {
        case .container: return "Customize card"
        case .volume: return "Customize volume"
        case .image, .imageGroup, .imageTag: return "Customize image style"
        }
    }

    private var overrideToggleTitle: String {
        if case .imageTag = target { return "Override group style" }
        return "Override image style"
    }

    private var overrideToggleHint: String {
        if case .imageTag = target {
            return "Turn this on to style only this tag. Leave it off to inherit the image group's style."
        }
        return "Turn this on to customize only this container. Leave it off to inherit the image style."
    }

    private var nicknameLabel: String {
        if case .container = target { return "Nickname" }
        return "Display name"
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
            return "Default for this local image group"
        case .imageTag:
            return "Style for \(Format.shortImage(target.image))"
        case .image:
            return "Default for every container from \(Format.shortImage(target.image))"
        case .volume:
            return "Style for this volume"
        case .container:
            return nil
        }
    }

    private var settingsDisabled: Bool {
        target.supportsInheritance && !overrideContainerStyle
    }

    private func widgetEnabled(_ index: Int) -> Bool {
        style.widget(at: index).enabled
    }

    private func widgetEnabledBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { style.widget(at: index).enabled },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.enabled = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetMetricBinding(_ index: Int) -> Binding<GraphMetric> {
        Binding(
            get: { style.widget(at: index).metric },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.metric = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetStyleBinding(_ index: Int) -> Binding<GraphStyle> {
        Binding(
            get: { style.widget(at: index).style },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.style = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetShowIconBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { style.widget(at: index).showIcon },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.showIcon = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetShowTextBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { style.widget(at: index).showText },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.showText = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    /// Whether there is a saved style to reset — a per-container override, or an image default.
    /// When false the Reset button is disabled (greyed, not active) rather than a no-op.
    private var canReset: Bool {
        switch target {
        case .image(let reference), .imageTag(let reference, _):
            return app.personalization.imageDefault(for: reference) != nil
        case .imageGroup(let id, _):
            return app.personalization.imageGroupDefault(for: id) != nil
        case .container(let snapshot): return app.personalization.hasOverride(id: snapshot.id)
        case .volume(let name): return app.personalization.volumeStyle(for: name) != nil
        }
    }

    private var overrideBinding: Binding<Bool> {
        Binding {
            overrideContainerStyle
        } set: { newValue in
            overrideContainerStyle = newValue
            // Seed the editable style: from the saved own-style when turning the override on, or the
            // inherited parent style (read-only, disabled) when turning it off.
            switch target {
            case .container, .imageTag:
                style = newValue ? ownStyle() : inheritedStyle()
            default:
                break
            }
        }
    }

    private func save() {
        switch target {
        case .image(let reference):
            app.personalization.setImageDefault(style, for: reference)
        case .imageTag(let reference, _):
            if overrideContainerStyle {
                app.personalization.setImageDefault(style, for: reference)
            } else {
                app.personalization.clearImageDefault(for: reference)   // back to inheriting the group
            }
        case .imageGroup(let id, _):
            app.personalization.setImageGroupDefault(style, for: id)
        case .container(let snapshot):
            if overrideContainerStyle {
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
        case .container(let snapshot): app.personalization.clearOverride(id: snapshot.id)
        case .volume(let name): app.personalization.clearVolumeStyle(for: name)
        }
        dismiss()
    }

    private func applyToImage() {
        guard case .container(let snapshot) = target else { return }
        app.personalization.setImageDefault(style, for: snapshot.image)
        app.personalization.clearOverride(id: snapshot.id)
        overrideContainerStyle = false
        dismiss()
    }

    /// The style this target inherits when its override is off: a container inherits the image style;
    /// a tag inherits its group's style.
    private func inheritedStyle() -> Personalization {
        switch target {
        case .container(let snapshot): return app.imageStyle(for: snapshot.image)
        case .imageTag(_, let groupID): return groupID.map { app.imageGroupStyle(forID: $0) } ?? Personalization()
        default: return Personalization()
        }
    }

    /// The target's own saved style when overriding (falls back to the inherited style as a starting
    /// point if nothing's saved yet).
    private func ownStyle() -> Personalization {
        switch target {
        case .container(let snapshot):
            return app.personalization.hasOverride(id: snapshot.id) ? app.containerStyle(for: snapshot) : inheritedStyle()
        case .imageTag(let reference, _):
            return app.personalization.imageDefault(for: reference) ?? inheritedStyle()
        default: return inheritedStyle()
        }
    }

}

/// A 360° gradient-direction control: a draggable dial plus a degree readout.
struct GradientAngleControl: View {
    @Binding var angle: Double

    var body: some View {
        LabeledContent("Direction") {
            HStack(spacing: Tokens.Space.m) {
                AngleDial(angle: $angle).frame(width: 36, height: 36)
                Slider(value: $angle, in: 0...360, step: 1)
                Text("\(Int(angle))°").monospacedDigit().frame(width: 40)
            }
        }
    }
}

/// A small dial knob whose pointer reflects the gradient angle; drag to set.
struct AngleDial: View {
    @Binding var angle: Double

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radians = angle * .pi / 180
            let knob = CGPoint(x: center.x + cos(radians) * (radius - 4),
                               y: center.y + sin(radians) * (radius - 4))
            ZStack {
                Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
                Circle().fill(.tint).frame(width: 7, height: 7).position(knob)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var deg = atan2(dy, dx) * 180 / .pi
                        if deg < 0 { deg += 360 }
                        angle = deg
                    }
            )
        }
    }
}
