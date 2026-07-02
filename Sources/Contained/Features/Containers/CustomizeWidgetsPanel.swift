import SwiftUI
import ContainedDesignSystem

/// Widget-specific controls for `CustomizeSheet`, split out so the sheet owns the target/persistence
/// workflow while this view owns per-widget ordering, metric, and chart editing.
struct CustomizeWidgetsPanel: View {
    @Binding var style: Personalization
    let graphOptions: [GraphMetric]
    let settingsDisabled: Bool

    private var activeWidgetIndices: [Int] {
        style.widgets.indices.filter { style.widget(at: $0).enabled }
    }

    private var canAddWidget: Bool {
        activeWidgetIndices.count < Personalization.widgetSlotCount
    }

    var body: some View {
        LazyVStack(spacing: Tokens.Space.l) {
            ForEach(activeWidgetIndices, id: \.self) { index in
                widgetSection(index)
            }
            addWidgetSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func widgetSection(_ index: Int) -> some View {
        PanelSection(header: widgetTitle(for: index)) {
            widgetOrderControls(index)
            Divider()
            widgetDisplayOptions(index)
            Divider()
            widgetDataOptions(index)
            Divider()
            widgetChartOptions(index)
        }
        .disabled(settingsDisabled)
        .opacity(settingsDisabled ? 0.48 : 1)
    }

    private var addWidgetSection: some View {
        PanelSection(header: "Widgets",
                     footer: "\(activeWidgetIndices.count) of \(Personalization.widgetSlotCount) widgets") {
            PanelRow(title: "Add widget",
                     subtitle: canAddWidget ? "Add another metric chip or chart to this card." : "All widget slots are in use.") {
                Button { addWidget() } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(!canAddWidget)
            }
        }
        .disabled(settingsDisabled)
        .opacity(settingsDisabled ? 0.48 : 1)
    }

    private func widgetOrderControls(_ index: Int) -> some View {
        let position = activeWidgetIndices.firstIndex(of: index) ?? 0
        return PanelRow(title: "Order", subtitle: "Move or remove this widget.") {
            HStack(spacing: Tokens.Space.xs) {
                Button { moveWidget(index, by: -1) } label: {
                    Label("Move up", systemImage: "chevron.up").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(position == 0)
                .help("Move widget up")

                Button { moveWidget(index, by: 1) } label: {
                    Label("Move down", systemImage: "chevron.down").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(position >= activeWidgetIndices.count - 1)
                .help("Move widget down")

                Button(role: .destructive) { removeWidget(index) } label: {
                    Label("Remove", systemImage: "minus.circle").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Remove widget")
            }
        }
    }

    @ViewBuilder
    private func widgetDisplayOptions(_ index: Int) -> some View {
        widgetGroupLabel("Display", systemImage: "paintpalette")
        PanelToggleRow(title: "Show icon", isOn: widgetBinding(index, \.showIcon))
        if style.widget(at: index).showIcon {
            PanelField(label: "Icon") {
                TextField("", text: widgetBinding(index, \.icon),
                          prompt: Text(style.widget(at: index).metric.systemImage))
                    .textFieldStyle(.roundedBorder)
            }
        }
        PanelToggleRow(title: "Show text", isOn: widgetBinding(index, \.showText))
        PanelRow(title: "Color") {
            TintSelector(optionalSelection: widgetBinding(index, \.tint), automaticLabel: "Card Color")
        }
    }

    @ViewBuilder
    private func widgetDataOptions(_ index: Int) -> some View {
        widgetGroupLabel("Data", systemImage: "waveform.path.ecg")
        PanelRow(title: "Metric") {
            Picker("", selection: widgetMetricBinding(index)) {
                ForEach(graphOptions) {
                    Label(graphLabel($0), systemImage: $0.systemImage).tag($0)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
        if widgetStyle(index).requiresSecondaryMetric {
            if let fallback = secondaryMetricFallback(for: index) {
                PanelRow(title: "Compare") {
                    Picker("", selection: widgetSecondaryMetricBinding(index, fallback: fallback)) {
                        ForEach(graphOptions.filter { $0 != style.widget(at: index).metric }) {
                            Label(graphLabel($0), systemImage: $0.systemImage).tag($0)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            } else {
                PanelRow(title: "Compare", subtitle: "This graph needs a second metric.")
            }
        }
    }

    @ViewBuilder
    private func widgetChartOptions(_ index: Int) -> some View {
        let chartStyle = widgetStyle(index)
        widgetGroupLabel("Chart", systemImage: "chart.xyaxis.line")
        PanelRow(title: "Type") {
            Picker("", selection: widgetStyleBinding(index)) {
                ForEach(GraphStyle.allCases) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
        if chartStyle == .area {
            PanelToggleRow(title: "Gradient fill", isOn: widgetBinding(index, \.areaUsesGradient))
        }
        if chartStyle.usesLineOptions {
            PanelRow(title: "Interpolation") {
                Picker("", selection: widgetBinding(index, \.interpolation)) {
                    ForEach(WidgetInterpolation.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            sliderRow("Line width",
                      value: widgetBinding(index, \.lineWidth),
                      range: 0.75...4,
                      step: 0.25,
                      readout: String(format: "%.1f", style.widget(at: index).lineWidth))
        }
        if chartStyle.usesPointOptions {
            sliderRow("Point size",
                      value: widgetBinding(index, \.pointSize),
                      range: 8...44,
                      step: 1,
                      readout: wholeNumberReadout(style.widget(at: index).pointSize))
        }
        if chartStyle.usesBarOptions {
            sliderRow("Bar width",
                      value: widgetBinding(index, \.barWidth),
                      range: 2...14,
                      step: 1,
                      readout: wholeNumberReadout(style.widget(at: index).barWidth))
        }
    }

    private func sliderRow(_ title: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           step: Double,
                           readout: String) -> some View {
        PanelRow(title: title) {
            HStack(spacing: Tokens.Space.s) {
                Slider(value: value, in: range, step: step)
                Text(readout)
                    .monospacedDigit()
                    .frame(width: Tokens.FormWidth.shortReadout)
            }
        }
    }

    private func widgetGroupLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func widgetTitle(for index: Int) -> String {
        let position = activeWidgetIndices.firstIndex(of: index) ?? 0
        return "Widget \(position + 1)"
    }

    private func graphLabel(_ metric: GraphMetric) -> String {
        guard graphOptions.allSatisfy({ $0 == .diskRead || $0 == .diskWrite }) else {
            return metric.displayName
        }
        switch metric {
        case .diskRead: return "Read"
        case .diskWrite: return "Write"
        default: return metric.displayName
        }
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
        style.widgets.swapAt(index, indices[targetPosition])
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

    private func widgetBinding<Value>(_ index: Int,
                                      _ keyPath: WritableKeyPath<WidgetConfiguration, Value>) -> Binding<Value> {
        Binding {
            style.widget(at: index)[keyPath: keyPath]
        } set: { newValue in
            var widget = style.widget(at: index)
            widget[keyPath: keyPath] = newValue
            style.setWidget(widget, at: index)
        }
    }

    private func widgetMetricBinding(_ index: Int) -> Binding<GraphMetric> {
        Binding {
            style.widget(at: index).metric
        } set: { newValue in
            var widget = style.widget(at: index)
            widget.metric = newValue
            if widget.secondaryMetric == newValue {
                widget.secondaryMetric = widget.style.resolvedSecondaryMetric(primary: newValue,
                                                                              requested: nil,
                                                                              options: graphOptions)
            }
            style.setWidget(widget, at: index)
        }
    }

    private func widgetStyleBinding(_ index: Int) -> Binding<GraphStyle> {
        Binding {
            style.widget(at: index).style
        } set: { newValue in
            var widget = style.widget(at: index)
            widget.style = newValue
            widget.secondaryMetric = newValue.resolvedSecondaryMetric(primary: widget.metric,
                                                                      requested: widget.secondaryMetric,
                                                                      options: graphOptions)
            style.setWidget(widget, at: index)
        }
    }

    private func widgetSecondaryMetricBinding(_ index: Int, fallback: GraphMetric) -> Binding<GraphMetric> {
        Binding {
            let widget = style.widget(at: index)
            return widget.style.resolvedSecondaryMetric(primary: widget.metric,
                                                        requested: widget.secondaryMetric,
                                                        options: graphOptions) ?? fallback
        } set: { newValue in
            var widget = style.widget(at: index)
            widget.secondaryMetric = newValue == widget.metric ? fallback : newValue
            style.setWidget(widget, at: index)
        }
    }

    private func wholeNumberReadout(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}
