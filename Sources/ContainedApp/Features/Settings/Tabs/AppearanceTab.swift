import SwiftUI
import ContainedDesignSystem
import ContainedCore

// MARK: - Appearance

struct AppearanceTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        LazyVStack(spacing: DesignTokens.Space.l) {
            PanelSection(header: AppText.string("settings.appearance.theme", defaultValue: "Theme")) {
                PanelRow(title: AppText.string("settings.appearance.appearance", defaultValue: "Appearance")) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.localizedDisplayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                PanelRow(title: AppText.string("settings.appearance.accentTint", defaultValue: "Accent tint")) {
                    TintSelector(selection: $settings.accentTint) { $0.localizedDisplayName }
                }
            }

            PanelSection(header: AppText.string("settings.appearance.layout", defaultValue: "Layout")) {
                PanelRow(title: AppText.string("settings.appearance.cardSize", defaultValue: "Card size")) {
                    Picker("", selection: $settings.density) {
                        ForEach(CardDensity.allCases) { Text($0.localizedDisplayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                PanelToggleRow(title: AppText.string("settings.appearance.showInfoTips", defaultValue: "Show info tips"),
                               isOn: $settings.showInfoTips)
            }

            PanelSection(header: AppText.string("settings.appearance.materials", defaultValue: "Materials"),
                         footer: AppText.string("settings.appearance.materials.footer", defaultValue: "Glass options use Liquid Glass. Other options use macOS vibrancy and follow the window background.")) {
                PanelRow(title: AppText.string("settings.appearance.mainBackgroundMaterial", defaultValue: "Main background material"),
                         info: AppText.string("settings.appearance.mainBackgroundMaterial.info", defaultValue: "Changes the material behind the main container grid.")) {
                    materialMenu($settings.windowMaterial)
                }
                PanelRow(title: AppText.string("settings.appearance.panelSheetMaterial", defaultValue: "Panel & sheet material"),
                         info: AppText.string("settings.appearance.panelSheetMaterial.info", defaultValue: "Changes floating panels, popovers, and sheets such as Settings and create/edit flows.")) {
                    materialMenu($settings.modalMaterial)
                }
                PanelRow(title: AppText.string("settings.appearance.cardMaterial", defaultValue: "Card material"),
                         info: AppText.string("settings.appearance.cardMaterial.info", defaultValue: "Changes all cards, including compact cards and expanded detail cards.")) {
                    materialMenu($settings.cardMaterial)
                }
                PanelRow(title: AppText.string("settings.appearance.buttonMaterial", defaultValue: "Button material"),
                         info: AppText.string("settings.appearance.buttonMaterial.info", defaultValue: "Changes toolbar glass buttons and grouped icon controls.")) {
                    materialMenu($settings.buttonMaterial)
                }
            }

            PanelSection(header: AppText.string("settings.appearance.buttonTint", defaultValue: "Button tint"),
                         footer: AppText.string("settings.appearance.buttonTint.footer", defaultValue: "Button tint uses the same color layer model as card backgrounds, applied inside toolbar glass controls."),
                         enabled: $settings.buttonTintEnabled) {
                PanelRow(title: AppText.tint) {
                    TintSelector(selection: $settings.buttonTint) { $0.localizedDisplayName }
                }
                PanelRow(title: AppText.string("settings.appearance.opacity", defaultValue: "Opacity")) {
                    HStack(spacing: DesignTokens.Space.s) {
                        Slider(value: $settings.buttonTintOpacity, in: 0.05...0.6)
                            .frame(width: DesignTokens.FormWidth.compactSlider)
                        Text(Format.percent(settings.buttonTintOpacity))
                            .monospacedDigit()
                            .frame(width: DesignTokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: AppText.string("settings.appearance.gradient", defaultValue: "Gradient"),
                               isOn: $settings.buttonTintGradient)
                if settings.buttonTintGradient {
                    GradientAngleControl(angle: $settings.buttonTintGradientAngle, title: AppText.direction)
                }
                PanelRow(title: AppText.string("settings.appearance.blendMode", defaultValue: "Blend mode")) {
                    Picker("", selection: $settings.buttonTintBlendMode) {
                        ForEach(ColorLayerBlendMode.allCases) { mode in
                            Text(mode.localizedDisplayName).tag(mode)
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
            ForEach(WindowMaterial.allCases) { Text($0.localizedDisplayName).tag($0) }
        }
        .labelsHidden().fixedSize()
    }
}

private struct ImageDefaultStyleSection: View {
    @Environment(AppModel.self) private var app
    @Bindable var settings: SettingsStore

    private var style: Personalization { app.personalization.defaultImageStyle }

    var body: some View {
        PanelSection(header: AppText.string("settings.appearance.defaultImageCardStyle", defaultValue: "Default image card style"),
                     footer: AppText.string("settings.appearance.defaultImageCardStyle.footer", defaultValue: "When on, image groups, image rows, and containers without their own style inherit this design. Specific image, image-group, tag, and container styles remain local overrides above this default."),
                     enabled: $settings.imageDefaultStyleEnabled) {
            HStack(spacing: DesignTokens.Space.m) {
                DesignCardIconChip(symbol: style.symbol, tint: style.color)
                VStack(alignment: .leading, spacing: DesignTokens.DesignCard.compactTextSpacing) {
                    Text(style.displayName(fallback: AppText.string("settings.appearance.imageCards", defaultValue: "Image cards")))
                    Text(AppText.string("settings.appearance.imageCards.inherited", defaultValue: "Inherited unless an image, group, tag, or container overrides it"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            PanelRow(title: AppText.string("settings.appearance.color", defaultValue: "Color")) {
                TintSelector(selection: styleBinding(\.tint)) { $0.localizedDisplayName }
            }
            PanelToggleRow(title: AppText.string("settings.appearance.customIcon", defaultValue: "Custom icon"),
                           isOn: styleBinding(\.iconEnabled))
            if style.iconEnabled {
                PanelRow(title: AppText.string("settings.appearance.icon", defaultValue: "Icon")) {
                    TextField("", text: styleBinding(\.icon), prompt: Text("SF Symbol, e.g. shippingbox.fill"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: DesignTokens.FormWidth.tintColorHex)
                }
            }
            PanelToggleRow(title: AppText.string("settings.appearance.colorCardBackground", defaultValue: "Color the card background"),
                           isOn: styleBinding(\.fillBackground))
            if style.fillBackground {
                PanelRow(title: AppText.string("settings.appearance.opacity", defaultValue: "Opacity")) {
                    HStack(spacing: DesignTokens.Space.s) {
                        Slider(value: styleBinding(\.backgroundOpacity), in: 0.05...0.6)
                            .frame(width: DesignTokens.FormWidth.compactSlider)
                        Text(Format.percent(style.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: DesignTokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: AppText.string("settings.appearance.gradient", defaultValue: "Gradient"),
                               isOn: styleBinding(\.gradient))
                if style.gradient {
                    GradientAngleControl(angle: styleBinding(\.gradientAngle), title: AppText.direction)
                }
                PanelRow(title: AppText.string("settings.appearance.blendMode", defaultValue: "Blend mode")) {
                    Picker("", selection: styleBinding(\.backgroundBlendMode)) {
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
