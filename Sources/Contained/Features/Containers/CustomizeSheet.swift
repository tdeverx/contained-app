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
        /// Targets that inherit from a parent and so offer an override toggle: containers inherit their
        /// image style, image/group styles inherit the Settings default, and tags inherit their group.
        var supportsInheritance: Bool {
            switch self {
            case .container, .image, .imageGroup, .imageTag: return true
            case .volume: return false
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
            PanelHeader(symbol: "paintbrush.pointed",
                        title: headerTitle,
                        subtitle: imageSubtitle) {
                GlassButton {
                    GlassButtonItem(systemName: "checkmark", help: "Save") { save() }
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true) { dismiss() }
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
                    ForEach(activeWidgetIndices, id: \.self) { index in
                        Section {
                            widgetEditor(index)
                        } header: {
                            Text(widgetTitle(for: index))
                        }
                        .disabled(settingsDisabled)
                        .opacity(settingsDisabled ? 0.48 : 1)
                    }

                    Section {
                        addWidgetButton
                    } header: {
                        Text("Widgets")
                    } footer: {
                        Text("\(activeWidgetIndices.count) of \(Personalization.widgetSlotCount) widgets")
                    }
                    .disabled(settingsDisabled)
                    .opacity(settingsDisabled ? 0.48 : 1)
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
                let own = app.personalization.imageDefault(for: reference)
                overrideContainerStyle = own != nil
                style = own ?? inheritedStyle()
            case .imageTag(let reference, _):
                // A tag inherits its group's style unless it has its own saved default (override on).
                let own = app.personalization.imageDefault(for: reference)
                overrideContainerStyle = own != nil
                style = own ?? inheritedStyle()
            case .imageGroup(let id, _):
                let own = app.personalization.imageGroupDefault(for: id)
                overrideContainerStyle = own != nil
                style = own ?? inheritedStyle()
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
        switch target {
        case .container: return "Override image style"
        case .image, .imageGroup: return "Override default image card design"
        case .imageTag: return "Override group style"
        case .volume: return "Override style"
        }
    }

    private var overrideToggleHint: String {
        switch target {
        case .container:
            return "Turn this on to customize only this container. Leave it off to inherit the image style."
        case .image:
            return "Turn this on to style containers from this exact image. Leave it off to inherit the default image card design from Settings."
        case .imageGroup:
            return "Turn this on to style this image group. Leave it off to inherit the default image card design from Settings."
        case .imageTag:
            return "Turn this on to style only this tag. Leave it off to inherit the image group's style."
        case .volume:
            return ""
        }
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

    private var activeWidgetIndices: [Int] {
        style.widgets.indices.filter { style.widget(at: $0).enabled }
    }

    private var canAddWidget: Bool {
        activeWidgetIndices.count < Personalization.widgetSlotCount
    }

    private var addWidgetButton: some View {
        Button { addWidget() } label: {
            Label("Add widget", systemImage: "plus")
        }
        .disabled(!canAddWidget)
        .foregroundStyle(canAddWidget ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
    }

    private func widgetTitle(for index: Int) -> String {
        let position = activeWidgetIndices.firstIndex(of: index) ?? 0
        return "Widget \(position + 1)"
    }

    @ViewBuilder
    private func widgetEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.s) {
                let position = activeWidgetIndices.firstIndex(of: index) ?? 0
                Label(widgetTitle(for: index), systemImage: style.widget(at: index).resolvedSystemImage)
                    .font(.callout.weight(.medium))
                Spacer()
                Button { moveWidget(index, by: -1) } label: {
                    Label("Move widget up", systemImage: "chevron.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(position == 0)
                .help("Move widget up")
                Button { moveWidget(index, by: 1) } label: {
                    Label("Move widget down", systemImage: "chevron.down")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(position >= activeWidgetIndices.count - 1)
                .help("Move widget down")
                Button(role: .destructive) { removeWidget(index) } label: {
                    Label("Remove widget", systemImage: "minus.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Remove widget")
            }

            widgetDisplayOptions(index)
            widgetDataOptions(index)
            widgetChartOptions(index)
        }
        .padding(.vertical, Tokens.Space.xs)
    }

    private func widgetGroupLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func widgetDisplayOptions(_ index: Int) -> some View {
        widgetGroupLabel("Display", systemImage: "paintpalette")
        Toggle("Show icon", isOn: widgetShowIconBinding(index))
        if style.widget(at: index).showIcon {
            TextField("Icon", text: widgetIconBinding(index),
                      prompt: Text(style.widget(at: index).metric.systemImage))
        }
        Toggle("Show text", isOn: widgetShowTextBinding(index))
        LabeledContent("Color") {
            TintSelector(optionalSelection: widgetTintBinding(index), automaticLabel: "Card Color")
        }
    }

    @ViewBuilder
    private func widgetDataOptions(_ index: Int) -> some View {
        widgetGroupLabel("Data", systemImage: "waveform.path.ecg")
        Picker("Metric", selection: widgetMetricBinding(index)) {
            ForEach(graphOptions) {
                Label(graphLabel($0), systemImage: $0.systemImage).tag($0)
            }
        }
        if widgetStyle(index).requiresSecondaryMetric {
            if let fallback = secondaryMetricFallback(for: index) {
                Picker("Compare", selection: widgetSecondaryMetricBinding(index, fallback: fallback)) {
                    ForEach(graphOptions.filter { $0 != style.widget(at: index).metric }) {
                        Label(graphLabel($0), systemImage: $0.systemImage).tag($0)
                    }
                }
            } else {
                Text("This graph needs a second metric.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func widgetChartOptions(_ index: Int) -> some View {
        let chartStyle = widgetStyle(index)
        widgetGroupLabel("Chart", systemImage: "chart.xyaxis.line")
        Picker("Type", selection: widgetStyleBinding(index)) {
            ForEach(GraphStyle.allCases) { Text($0.displayName).tag($0) }
        }
        if chartStyle == .area {
            Toggle("Gradient fill", isOn: widgetAreaGradientBinding(index))
        }
        if chartStyle.usesLineOptions {
            Picker("Interpolation", selection: widgetInterpolationBinding(index)) {
                ForEach(WidgetInterpolation.allCases) { Text($0.displayName).tag($0) }
            }
            sliderRow("Line Width",
                      value: widgetLineWidthBinding(index),
                      range: 0.75...4,
                      step: 0.25,
                      readout: widgetLineWidthReadout(index))
        }
        if chartStyle.usesPointOptions {
            sliderRow("Point Size",
                      value: widgetPointSizeBinding(index),
                      range: 8...44,
                      step: 1,
                      readout: widgetWholeNumberReadout(style.widget(at: index).pointSize))
        }
        if chartStyle.usesBarOptions {
            sliderRow("Bar Width",
                      value: widgetBarWidthBinding(index),
                      range: 2...14,
                      step: 1,
                      readout: widgetWholeNumberReadout(style.widget(at: index).barWidth))
        }
    }

    private func sliderRow(_ title: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           step: Double,
                           readout: String) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: range, step: step)
            Text(readout)
                .monospacedDigit()
                .frame(width: Tokens.FormWidth.shortReadout)
        }
    }

    private func widgetEnabled(_ index: Int) -> Bool {
        style.widget(at: index).enabled
    }

    private func addWidget() {
        guard canAddWidget,
              let index = style.widgets.indices.first(where: { !style.widget(at: $0).enabled }) else { return }
        var widget = style.widget(at: index)
        widget.enabled = true
        widget.metric = nextWidgetMetric()
        widget.secondaryMetric = widget.style.resolvedSecondaryMetric(primary: widget.metric,
                                                                      requested: widget.secondaryMetric,
                                                                      options: graphOptions)
        style.setWidget(widget, at: index)
    }

    private func removeWidget(_ index: Int) {
        var widget = style.widget(at: index)
        widget.enabled = false
        style.setWidget(widget, at: index)
    }

    private func moveWidget(_ index: Int, by offset: Int) {
        let indices = activeWidgetIndices
        guard let position = indices.firstIndex(of: index) else { return }
        let targetPosition = position + offset
        guard indices.indices.contains(targetPosition) else { return }
        let targetIndex = indices[targetPosition]
        style.widgets.swapAt(index, targetIndex)
    }

    private func nextWidgetMetric() -> GraphMetric {
        let activeMetrics = Set(activeWidgetIndices.map { style.widget(at: $0).metric })
        return graphOptions.first { !activeMetrics.contains($0) } ?? graphOptions.first ?? .cpu
    }

    private func widgetStyle(_ index: Int) -> GraphStyle {
        style.widget(at: index).style
    }

    private func secondaryMetricFallback(for index: Int) -> GraphMetric? {
        let widget = style.widget(at: index)
        return widget.style.resolvedSecondaryMetric(primary: widget.metric,
                                                    requested: widget.secondaryMetric,
                                                    options: graphOptions)
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
                if widget.secondaryMetric == newValue {
                    widget.secondaryMetric = widget.style.resolvedSecondaryMetric(primary: newValue,
                                                                                  requested: nil,
                                                                                  options: graphOptions)
                }
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetTintBinding(_ index: Int) -> Binding<AppTint?> {
        Binding(
            get: { style.widget(at: index).tint },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.tint = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetIconBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { style.widget(at: index).icon },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.icon = newValue
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
                widget.secondaryMetric = newValue.resolvedSecondaryMetric(primary: widget.metric,
                                                                          requested: widget.secondaryMetric,
                                                                          options: graphOptions)
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetAreaGradientBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { style.widget(at: index).areaUsesGradient },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.areaUsesGradient = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetInterpolationBinding(_ index: Int) -> Binding<WidgetInterpolation> {
        Binding(
            get: { style.widget(at: index).interpolation },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.interpolation = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetLineWidthBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { style.widget(at: index).lineWidth },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.lineWidth = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetPointSizeBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { style.widget(at: index).pointSize },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.pointSize = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetBarWidthBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { style.widget(at: index).barWidth },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.barWidth = newValue
                style.setWidget(widget, at: index)
            }
        )
    }

    private func widgetLineWidthReadout(_ index: Int) -> String {
        String(format: "%.1f", style.widget(at: index).lineWidth)
    }

    private func widgetWholeNumberReadout(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    private func widgetSecondaryMetricBinding(_ index: Int, fallback: GraphMetric) -> Binding<GraphMetric> {
        Binding(
            get: {
                let widget = style.widget(at: index)
                return widget.style.resolvedSecondaryMetric(primary: widget.metric,
                                                            requested: widget.secondaryMetric,
                                                            options: graphOptions) ?? fallback
            },
            set: { newValue in
                var widget = style.widget(at: index)
                widget.secondaryMetric = newValue == widget.metric ? fallback : newValue
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
            case .container, .image, .imageGroup, .imageTag:
                style = newValue ? ownStyle() : inheritedStyle()
            default:
                break
            }
        }
    }

    private func save() {
        switch target {
        case .image(let reference):
            if overrideContainerStyle {
                app.personalization.setImageDefault(style, for: reference)
            } else {
                app.personalization.clearImageDefault(for: reference)
            }
        case .imageTag(let reference, _):
            if overrideContainerStyle {
                app.personalization.setImageDefault(style, for: reference)
            } else {
                app.personalization.clearImageDefault(for: reference)   // back to inheriting the group
            }
        case .imageGroup(let id, _):
            if overrideContainerStyle {
                app.personalization.setImageGroupDefault(style, for: id)
            } else {
                app.personalization.clearImageGroupDefault(for: id)
            }
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
    /// an image/group inherits Settings; a tag inherits its group's style.
    private func inheritedStyle() -> Personalization {
        switch target {
        case .container(let snapshot): return app.imageStyle(for: snapshot.image)
        case .image, .imageGroup: return app.defaultImageStyle
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
        case .image(let reference), .imageTag(let reference, _):
            return app.personalization.imageDefault(for: reference) ?? inheritedStyle()
        case .imageGroup(let id, _):
            return app.personalization.imageGroupDefault(for: id) ?? inheritedStyle()
        default: return inheritedStyle()
        }
    }

}
