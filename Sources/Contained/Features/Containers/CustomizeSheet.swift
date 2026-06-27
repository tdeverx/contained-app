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

        var id: String {
            switch self {
            case .container(let s): return "container:\(s.id)"
            case .image(let r):     return "image:\(r)"
            }
        }
        var image: String {
            switch self {
            case .container(let s): return s.image
            case .image(let r):     return r
            }
        }
        var isImage: Bool { if case .image = self { return true }; return false }
        /// The snapshot the live preview renders — the real one for a container, a synthetic one for
        /// an image (so we can show how cards from that image will look).
        var previewSnapshot: ContainerSnapshot {
            switch self {
            case .container(let s): return s
            case .image(let r):     return .placeholder(id: Format.shortImage(r), image: r)
            }
        }
    }

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let target: Target
    let presentation: Presentation

    /// Convenience initializer for the container case (keeps existing call sites working).
    init(snapshot: ContainerSnapshot, presentation: Presentation = .popover) {
        self.target = .container(snapshot)
        self.presentation = presentation
    }

    init(target: Target, presentation: Presentation = .sheet) {
        self.target = target
        self.presentation = presentation
    }

    @State private var style = Personalization()
    @State private var overrideContainerStyle = true
    @State private var loaded = false

    private var isPopoverPresentation: Bool { presentation == .popover }
    private var previewWidth: CGFloat { isPopoverPresentation ? 372 : 320 }
    private var previewDensity: CardDensity { .large }
    private var previewHeight: CGFloat { isPopoverPresentation ? 176 : 176 }
    private var panelSize: CGSize {
        isPopoverPresentation ? CGSize(width: 430, height: 520) : CGSize(width: 480, height: 600)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: target.isImage ? "Customize image style" : "Customize card",
                        subtitle: target.isImage ? "Default for every container from \(Format.shortImage(target.image))" : nil,
                        onCancel: { dismiss() }) {
                GlassCircleButton(systemName: "checkmark", prominent: true, help: "Save") { save() }
            }

            preview
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Tokens.Space.l)
                .padding(.top, Tokens.Space.xs)
                .padding(.bottom, Tokens.Space.s)

            Form {
                if !target.isImage {
                    Section("Inheritance") {
                        Toggle("Override image style", isOn: overrideBinding)
                            .fieldInfo("Turn this on to customize only this container. Leave it off to inherit the image style from the Images page.")
                    }
                }
                Section("Style") {
                    TextField(target.isImage ? "Display name" : "Nickname",
                              text: $style.nickname,
                              prompt: Text(target.isImage ? Format.shortImage(target.image) : target.previewSnapshot.id))
                    TextField("Icon", text: $style.icon, prompt: Text("SF Symbol, e.g. globe, bolt"))
                    LabeledContent("Color") { TintSelector(selection: $style.tint) }
                        .fieldInfo("\"App Accent\" (the linked swatch) follows the app accent from Settings, so the card tracks your theme. Pick any other color to pin this card.")
                    Picker("Graph", selection: $style.graphMetric) {
                        ForEach(GraphMetric.allCases) { Label($0.displayName, systemImage: $0.systemImage).tag($0) }
                    }
                }
                .disabled(settingsDisabled)
                .opacity(settingsDisabled ? 0.48 : 1)

                Section("Background") {
                    Toggle("Color the card background", isOn: $style.fillBackground)
                    if style.fillBackground {
                        LabeledContent("Opacity") {
                            Slider(value: $style.backgroundOpacity, in: 0.05...0.6)
                            Text(Format.percent(style.backgroundOpacity)).monospacedDigit().frame(width: 44)
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
                    if !target.isImage {
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
                style = app.personalization.resolved(id: snapshot.id, image: snapshot.image)
                overrideContainerStyle = app.personalization.hasOverride(id: snapshot.id)
            case .image(let reference):
                style = app.personalization.imageDefault(for: reference) ?? Personalization()
                overrideContainerStyle = true
            }
            loaded = true
        }
    }

    private var settingsDisabled: Bool {
        !target.isImage && !overrideContainerStyle
    }

    /// Whether there is a saved style to reset — a per-container override, or an image default.
    /// When false the Reset button is disabled (greyed, not active) rather than a no-op.
    private var canReset: Bool {
        switch target {
        case .image(let reference):    return app.personalization.imageDefault(for: reference) != nil
        case .container(let snapshot): return app.personalization.hasOverride(id: snapshot.id)
        }
    }

    private var overrideBinding: Binding<Bool> {
        Binding {
            overrideContainerStyle
        } set: { newValue in
            overrideContainerStyle = newValue
            if case .container(let snapshot) = target {
                style = newValue
                    ? app.personalization.resolved(id: snapshot.id, image: snapshot.image)
                    : inheritedStyle(for: snapshot)
            }
        }
    }

    private func save() {
        switch target {
        case .image(let reference):
            app.personalization.setImageDefault(style, for: reference)
        case .container(let snapshot):
            if overrideContainerStyle {
                app.personalization.setOverride(style, for: snapshot.id)
            } else {
                app.personalization.clearOverride(id: snapshot.id)
            }
        }
        dismiss()
    }

    private func reset() {
        switch target {
        case .image(let reference):    app.personalization.clearImageDefault(for: reference)
        case .container(let snapshot): app.personalization.clearOverride(id: snapshot.id)
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

    private func inheritedStyle(for snapshot: ContainerSnapshot) -> Personalization {
        app.personalization.imageDefault(for: snapshot.image) ?? Personalization()
    }

    /// A live preview using the real card view with fake "running" data, so users see how it looks
    /// in use while customizing. No section background — it floats on the sheet material.
    /// Uses the large card variant to match actual card display, with buttons disabled on hover
    /// and proper glass surface styling applied.
    private var preview: some View {
        ContainerCard(
            snapshot: target.previewSnapshot,
            style: style,
            density: previewDensity,
            stats: .sample(),
            history: StatsDelta.sampleHistory,
            isBusy: false,
            onTap: {}, onStart: {}, onStop: {}, onRestart: {}, onDelete: {},
            previewPresentation: .running
        )
        .frame(width: previewWidth)
        .frame(height: previewHeight)
        .allowsHitTesting(false)
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
