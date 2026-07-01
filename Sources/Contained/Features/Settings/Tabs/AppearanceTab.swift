import SwiftUI
import ContainedCore

// MARK: - Appearance

struct AppearanceTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection(header: "Theme") {
                PanelRow(title: "Appearance") {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                PanelRow(title: "Accent tint") {
                    TintSelector(selection: $settings.accentTint)
                }
            }

            PanelSection(header: "Layout") {
                PanelRow(title: "Card size") {
                    Picker("", selection: $settings.density) {
                        ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                PanelToggleRow(title: "Show info tips", isOn: $settings.showInfoTips)
            }

            PanelSection(header: "Materials",
                         footer: "Glass options use Liquid Glass. Other options use macOS vibrancy and follow the window background.") {
                PanelRow(title: "Main background material",
                         info: "Changes the material behind the main container grid.") {
                    materialMenu($settings.windowMaterial)
                }
                PanelRow(title: "Panel & sheet material",
                         info: "Changes floating panels, popovers, and sheets such as Settings and create/edit flows.") {
                    materialMenu($settings.modalMaterial)
                }
                PanelRow(title: "Card material",
                         info: "Changes all resource cards, including compact cards and expanded detail cards.") {
                    materialMenu($settings.cardMaterial)
                }
                PanelRow(title: "Button material",
                         info: "Changes toolbar glass buttons and grouped icon controls.") {
                    materialMenu($settings.buttonMaterial)
                }
            }

            PanelSection(header: "Button tint",
                         footer: "Button tint uses the same color layer model as card backgrounds, applied inside toolbar glass controls.",
                         enabled: $settings.buttonTintEnabled) {
                PanelRow(title: "Tint") {
                    TintSelector(selection: $settings.buttonTint)
                }
                PanelRow(title: "Opacity") {
                    HStack(spacing: Tokens.Space.s) {
                        Slider(value: $settings.buttonTintOpacity, in: 0.05...0.6).frame(width: 140)
                        Text(Format.percent(settings.buttonTintOpacity))
                            .monospacedDigit()
                            .frame(width: Tokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: "Gradient", isOn: $settings.buttonTintGradient)
                if settings.buttonTintGradient {
                    GradientAngleControl(angle: $settings.buttonTintGradientAngle)
                }
                PanelRow(title: "Blend mode") {
                    Picker("", selection: $settings.buttonTintBlendMode) {
                        ForEach(ColorLayerBlendMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            ImageDefaultStyleSection(settings: settings)
        }
    }

    private func materialMenu(_ binding: Binding<WindowMaterial>) -> some View {
        Picker("", selection: binding) {
            ForEach(WindowMaterial.allCases) { Text($0.displayName).tag($0) }
        }
        .labelsHidden().fixedSize()
    }
}

private struct ImageDefaultStyleSection: View {
    @Environment(AppModel.self) private var app
    @Bindable var settings: SettingsStore

    private var style: Personalization { app.personalization.defaultImageStyle }

    var body: some View {
        PanelSection(header: "Default image card style",
                     footer: "When on, image groups, image rows, and containers without their own style inherit this design. Specific image, image-group, tag, and container styles remain local overrides above this default.",
                     enabled: $settings.imageDefaultStyleEnabled) {
            HStack(spacing: Tokens.Space.m) {
                ResourceCardIconChip(symbol: style.symbol, tint: style.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.displayName(fallback: "Image cards"))
                    Text("Inherited unless an image, group, tag, or container overrides it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            PanelRow(title: "Color") {
                TintSelector(selection: styleBinding(\.tint))
            }
            PanelToggleRow(title: "Custom icon", isOn: styleBinding(\.iconEnabled))
            if style.iconEnabled {
                PanelRow(title: "Icon") {
                    TextField("", text: styleBinding(\.icon), prompt: Text("SF Symbol, e.g. shippingbox.fill"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }
            PanelToggleRow(title: "Color the card background", isOn: styleBinding(\.fillBackground))
            if style.fillBackground {
                PanelRow(title: "Opacity") {
                    HStack(spacing: Tokens.Space.s) {
                        Slider(value: styleBinding(\.backgroundOpacity), in: 0.05...0.6).frame(width: 140)
                        Text(Format.percent(style.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: Tokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: "Gradient", isOn: styleBinding(\.gradient))
                if style.gradient {
                    GradientAngleControl(angle: styleBinding(\.gradientAngle))
                }
                PanelRow(title: "Blend mode") {
                    Picker("", selection: styleBinding(\.backgroundBlendMode)) {
                        ForEach(ColorLayerBlendMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    private func styleBinding<Value>(_ keyPath: WritableKeyPath<Personalization, Value>) -> Binding<Value> {
        Binding {
            app.personalization.defaultImageStyle[keyPath: keyPath]
        } set: { newValue in
            var updated = app.personalization.defaultImageStyle
            updated[keyPath: keyPath] = newValue
            app.personalization.setDefaultImageStyle(updated)
        }
    }
}
