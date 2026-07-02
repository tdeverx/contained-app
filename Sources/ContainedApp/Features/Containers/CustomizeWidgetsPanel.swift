import SwiftUI
import ContainedDesignSystem
import ContainedCore

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
        LazyVStack(spacing: DesignTokens.Space.l) {
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
        PanelSection(header: AppText.string("customize.widgets", defaultValue: "Widgets"),
                     footer: AppText.string("customize.widgets.footer", defaultValue: "\(activeWidgetIndices.count) of \(Personalization.widgetSlotCount) widgets")) {
            PanelRow(title: AppText.string("customize.addWidget", defaultValue: "Add widget"),
                     subtitle: canAddWidget
                         ? AppText.string("customize.addWidget.subtitle", defaultValue: "Add another metric chip or chart to this card.")
                         : AppText.string("customize.addWidget.slotsFull", defaultValue: "All widget slots are in use.")) {
                Button { addWidget() } label: {
                    Label(AppText.add, systemImage: "plus")
                }
                .disabled(!canAddWidget)
            }
        }
        .disabled(settingsDisabled)
        .opacity(settingsDisabled ? 0.48 : 1)
    }

    private func widgetOrderControls(_ index: Int) -> some View {
        let position = activeWidgetIndices.firstIndex(of: index) ?? 0
        return PanelRow(title: AppText.string("customize.widget.order", defaultValue: "Order"),
                        subtitle: AppText.string("customize.widget.order.subtitle", defaultValue: "Move or remove this widget.")) {
            HStack(spacing: DesignTokens.Space.xs) {
                Button { moveWidget(index, by: -1) } label: {
                    Label(AppText.string("customize.widget.moveUp", defaultValue: "Move up"), systemImage: "chevron.up").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(position == 0)
                .help(AppText.string("customize.widget.moveUp.help", defaultValue: "Move widget up"))

                Button { moveWidget(index, by: 1) } label: {
                    Label(AppText.string("customize.widget.moveDown", defaultValue: "Move down"), systemImage: "chevron.down").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(position >= activeWidgetIndices.count - 1)
                .help(AppText.string("customize.widget.moveDown.help", defaultValue: "Move widget down"))

                Button(role: .destructive) { removeWidget(index) } label: {
                    Label(AppText.string("common.remove", defaultValue: "Remove"), systemImage: "minus.circle").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(AppText.string("customize.widget.remove.help", defaultValue: "Remove widget"))
            }
        }
    }

    @ViewBuilder
    private func widgetDisplayOptions(_ index: Int) -> some View {
        widgetGroupLabel(AppText.string("customize.widget.display", defaultValue: "Display"), systemImage: "paintpalette")
        PanelToggleRow(title: AppText.string("customize.widget.showIcon", defaultValue: "Show icon"), isOn: widgetBinding(index, \.showIcon))
        if style.widget(at: index).showIcon {
            PanelField(label: AppText.string("customize.icon", defaultValue: "Icon")) {
                TextField("", text: widgetBinding(index, \.icon),
                          prompt: Text(style.widget(at: index).metric.systemImage))
                    .textFieldStyle(.roundedBorder)
            }
        }
        PanelToggleRow(title: AppText.string("customize.widget.showText", defaultValue: "Show text"), isOn: widgetBinding(index, \.showText))
        PanelRow(title: AppText.string("customize.color", defaultValue: "Color")) {
            TintSelector(optionalSelection: widgetBinding(index, \.tint),
                         automaticLabel: AppText.cardColor) { $0.localizedDisplayName }
        }
    }

    @ViewBuilder
    private func widgetDataOptions(_ index: Int) -> some View {
        widgetGroupLabel(AppText.string("customize.widget.data", defaultValue: "Data"), systemImage: "waveform.path.ecg")
        PanelRow(title: AppText.string("customize.widget.metric", defaultValue: "Metric")) {
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
                PanelRow(title: AppText.string("customize.widget.compare", defaultValue: "Compare")) {
                    Picker("", selection: widgetSecondaryMetricBinding(index, fallback: fallback)) {
                        ForEach(graphOptions.filter { $0 != style.widget(at: index).metric }) {
                            Label(graphLabel($0), systemImage: $0.systemImage).tag($0)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            } else {
                PanelRow(title: AppText.string("customize.widget.compare", defaultValue: "Compare"),
                         subtitle: AppText.string("customize.widget.compare.subtitle", defaultValue: "This graph needs a second metric."))
            }
        }
    }

    @ViewBuilder
    private func widgetChartOptions(_ index: Int) -> some View {
        let chartStyle = widgetStyle(index)
        widgetGroupLabel(AppText.string("customize.widget.chart", defaultValue: "Chart"), systemImage: "chart.xyaxis.line")
        PanelRow(title: AppText.string("customize.widget.type", defaultValue: "Type")) {
            Picker("", selection: widgetStyleBinding(index)) {
                ForEach(GraphStyle.allCases) { Text($0.localizedDisplayName).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
        if chartStyle == .area {
            PanelToggleRow(title: AppText.string("customize.widget.gradientFill", defaultValue: "Gradient fill"), isOn: widgetBinding(index, \.areaUsesGradient))
        }
        if chartStyle.usesLineOptions {
            PanelRow(title: AppText.string("customize.widget.interpolation", defaultValue: "Interpolation")) {
                Picker("", selection: widgetBinding(index, \.interpolation)) {
                    ForEach(WidgetInterpolation.allCases) { Text($0.localizedDisplayName).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            sliderRow(AppText.string("customize.widget.lineWidth", defaultValue: "Line width"),
                      value: widgetBinding(index, \.lineWidth),
                      range: 0.75...4,
                      step: 0.25,
                      readout: String(format: "%.1f", style.widget(at: index).lineWidth))
        }
        if chartStyle.usesPointOptions {
            sliderRow(AppText.string("customize.widget.pointSize", defaultValue: "Point size"),
                      value: widgetBinding(index, \.pointSize),
                      range: 8...44,
                      step: 1,
                      readout: wholeNumberReadout(style.widget(at: index).pointSize))
        }
        if chartStyle.usesBarOptions {
            sliderRow(AppText.string("customize.widget.barWidth", defaultValue: "Bar width"),
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
            HStack(spacing: DesignTokens.Space.s) {
                Slider(value: value, in: range, step: step)
                Text(readout)
                    .monospacedDigit()
                    .frame(width: DesignTokens.FormWidth.shortReadout)
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
        return AppText.string("customize.widget.title", defaultValue: "Widget \(position + 1)")
    }

    private func graphLabel(_ metric: GraphMetric) -> String {
        guard graphOptions.allSatisfy({ $0 == .diskRead || $0 == .diskWrite }) else {
            return metric.displayName
        }
        switch metric {
        case .diskRead: return AppText.string("customize.widget.metric.read", defaultValue: "Read")
        case .diskWrite: return AppText.string("customize.widget.metric.write", defaultValue: "Write")
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
