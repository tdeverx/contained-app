import SwiftUI
import ContainedUI
import ContainedCore

// MARK: - Appearance

struct AppearanceTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        SettingsForm {
            Section(AppText.string("settings.appearance.theme", defaultValue: "Theme")) {
                UI.Form.Row(title: AppText.string("settings.appearance.appearance", defaultValue: "Appearance"),
                            isChanged: settings.appearance != .system) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(UI.Theme.Appearance.allCases) { Text($0.localizedDisplayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                UI.Form.Row(title: AppText.string("settings.appearance.accentTint", defaultValue: "Accent tint"),
                            isChanged: settings.accentTint != .multicolor) {
                    UI.Control.TintSelector(selection: $settings.accentTint,
                                            customLabel: AppText.customHexColor,
                                            inheritedAccentColor: Platform.systemAccentColor) {
                        $0 == .multicolor
                            ? AppText.string("tint.systemAccent", defaultValue: "System Accent")
                            : $0.localizedDisplayName
                    }
                }
                if settings.accentTint.isCustom {
                    UI.Form.Row(title: AppText.customHexColor) {
                        UI.Control.HexTintField(selection: $settings.accentTint)
                    }
                }
            }

            Section(AppText.string("settings.appearance.layout", defaultValue: "Layout")) {
                UI.Form.Row(title: AppText.string("settings.appearance.cardSize", defaultValue: "Card size"),
                            isChanged: settings.density != UI.Card.Density(stored: "")) {
                    Picker("", selection: $settings.density) {
                        ForEach(UI.Card.Density.allCases) { Text($0.localizedDisplayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                UI.Form.ToggleRow(title: AppText.string("settings.appearance.showInfoTips", defaultValue: "Show info tips"),
                                  isChanged: settings.showInfoTips != true,
                                  isOn: $settings.showInfoTips)
            }

            Section {
                UI.Form.Row(title: AppText.string("settings.appearance.mainBackgroundMaterial", defaultValue: "Main background material"),
                            info: AppText.string("settings.appearance.mainBackgroundMaterial.info", defaultValue: "Changes the material behind the main container grid."),
                            isChanged: settings.windowMaterial != .fullScreenUI) {
                    materialMenu($settings.windowMaterial)
                }
                UI.Form.Row(title: AppText.string("settings.appearance.panelSheetMaterial", defaultValue: "Panel & sheet material"),
                            info: AppText.string("settings.appearance.panelSheetMaterial.info", defaultValue: "Changes floating panels, popovers, and sheets such as Settings and create/edit flows."),
                            isChanged: settings.modalMaterial != .sheet) {
                    materialMenu($settings.modalMaterial)
                }
                UI.Form.Row(title: AppText.string("settings.appearance.cardMaterial", defaultValue: "Card material"),
                            info: AppText.string("settings.appearance.cardMaterial.info", defaultValue: "Changes all cards, including compact cards and expanded detail cards."),
                            isChanged: settings.cardMaterial != .glassRegular) {
                    materialMenu($settings.cardMaterial)
                }
                UI.Form.Row(title: AppText.string("settings.appearance.buttonMaterial", defaultValue: "Button material"),
                            info: AppText.string("settings.appearance.buttonMaterial.info", defaultValue: "Changes toolbar glass buttons and grouped icon controls."),
                            isChanged: settings.buttonMaterial != .glassClear) {
                    materialMenu($settings.buttonMaterial)
                }
            } header: {
                Text(AppText.string("settings.appearance.materials", defaultValue: "Materials"))
            } footer: {
                Text(AppText.string("settings.appearance.materials.footer", defaultValue: "Glass options use Liquid Glass. Other options use macOS vibrancy and follow the window background."))
            }

            Section {
                UI.Form.ToggleRow(title: AppText.string("common.enabled", defaultValue: "Enabled"),
                                  isChanged: settings.buttonTintEnabled != false,
                                  isOn: $settings.buttonTintEnabled)
                UI.Form.Row(title: AppText.tint,
                            isChanged: settings.buttonTint != .multicolor) {
                    UI.Control.TintSelector(selection: $settings.buttonTint,
                                            customLabel: AppText.customHexColor) { $0.localizedDisplayName }
                }
                if settings.buttonTint.isCustom {
                    UI.Form.Row(title: AppText.customHexColor) {
                        UI.Control.HexTintField(selection: $settings.buttonTint)
                    }
                }
                UI.Form.Row(title: AppText.string("settings.appearance.opacity", defaultValue: "Opacity"),
                            isChanged: settings.buttonTintOpacity != 0.18) {
                    HStack(spacing: UI.Layout.Spacing.s) {
                        Slider(value: $settings.buttonTintOpacity, in: 0.05...0.6)
                            .frame(width: UI.Form.Width.compactSlider)
                        Text(Format.percent(settings.buttonTintOpacity))
                            .monospacedDigit()
                            .frame(width: UI.Form.Width.shortReadout)
                    }
                }
                UI.Form.ToggleRow(title: AppText.string("settings.appearance.gradient", defaultValue: "Gradient"),
                                  isChanged: settings.buttonTintGradient != true,
                                  isOn: $settings.buttonTintGradient)
                if settings.buttonTintGradient {
                    UI.Control.GradientAngle(angle: $settings.buttonTintGradientAngle, title: AppText.direction)
                }
                UI.Form.Row(title: AppText.string("settings.appearance.blendMode", defaultValue: "Blend mode"),
                            isChanged: settings.buttonTintBlendMode != .softLight) {
                    Picker("", selection: $settings.buttonTintBlendMode) {
                        ForEach(UI.Theme.ColorBlendMode.allCases) { mode in
                            Text(mode.localizedDisplayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            } header: {
                Text(AppText.string("settings.appearance.buttonTint", defaultValue: "Button tint"))
            } footer: {
                Text(AppText.string("settings.appearance.buttonTint.footer", defaultValue: "Button tint uses the same color layer model as card backgrounds, applied inside toolbar glass controls."))
            }

            ImageDefaultStyleSection(settings: settings)
        }
    }

    private func materialMenu(_ binding: Binding<UI.Theme.WindowMaterial>) -> some View {
        Picker("", selection: binding) {
            ForEach(UI.Theme.WindowMaterial.allCases) { Text($0.localizedDisplayName).tag($0) }
        }
        .labelsHidden().fixedSize()
    }
}

private struct ImageDefaultStyleSection: View {
    @Environment(AppModel.self) private var app
    @Bindable var settings: SettingsStore

    private var style: Personalization { app.personalization.defaultImageStyle }

    var body: some View {
        Section {
            UI.Form.ToggleRow(title: AppText.string("common.enabled", defaultValue: "Enabled"),
                              isChanged: settings.imageDefaultStyleEnabled != true,
                              isOn: $settings.imageDefaultStyleEnabled)
            HStack(spacing: UI.Layout.Spacing.m) {
                UI.Card.IconChip(symbol: style.symbol, tint: style.color)
                VStack(alignment: .leading, spacing: UI.Card.Spacing.compactText) {
                    Text(style.displayName(fallback: AppText.string("settings.appearance.imageCards", defaultValue: "Image cards")))
                    Text(AppText.string("settings.appearance.imageCards.inherited", defaultValue: "Inherited unless an image, group, tag, or container overrides it"))
                        .designSecondaryCaption()
                }
                Spacer()
            }
            UI.Form.Row(title: AppText.string("settings.appearance.color", defaultValue: "Color"),
                        isChanged: style.tint != Personalization().tint) {
                UI.Control.TintSelector(selection: styleBinding(\.tint),
                                        customLabel: AppText.customHexColor) { $0.localizedDisplayName }
            }
            if style.tint.isCustom {
                UI.Form.Row(title: AppText.customHexColor) {
                    UI.Control.HexTintField(selection: styleBinding(\.tint))
                }
            }
            UI.Form.ToggleRow(title: AppText.string("settings.appearance.customIcon", defaultValue: "Custom icon"),
                              isChanged: style.iconEnabled != Personalization().iconEnabled,
                              isOn: styleBinding(\.iconEnabled))
            if style.iconEnabled {
                UI.Form.Field(label: AppText.string("settings.appearance.icon", defaultValue: "Icon"),
                              isChanged: style.icon != Personalization().icon) {
                    TextField("", text: styleBinding(\.icon), prompt: Text("SF Symbol, e.g. shippingbox.fill"))
                        .frame(width: UI.Form.Width.tintColorHex)
                }
            }
            UI.Form.ToggleRow(title: AppText.string("settings.appearance.colorCardBackground", defaultValue: "Color the card background"),
                              isChanged: style.fillBackground != Personalization().fillBackground,
                              isOn: styleBinding(\.fillBackground))
            if style.fillBackground {
                UI.Form.Row(title: AppText.string("settings.appearance.opacity", defaultValue: "Opacity"),
                            isChanged: style.backgroundOpacity != Personalization.defaultBackgroundOpacity) {
                    HStack(spacing: UI.Layout.Spacing.s) {
                        Slider(value: styleBinding(\.backgroundOpacity), in: 0.05...0.6)
                            .frame(width: UI.Form.Width.compactSlider)
                        Text(Format.percent(style.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: UI.Form.Width.shortReadout)
                    }
                }
                UI.Form.ToggleRow(title: AppText.string("settings.appearance.gradient", defaultValue: "Gradient"),
                                  isChanged: style.gradient != Personalization().gradient,
                                  isOn: styleBinding(\.gradient))
                if style.gradient {
                    UI.Control.GradientAngle(angle: styleBinding(\.gradientAngle), title: AppText.direction)
                }
                UI.Form.Row(title: AppText.string("settings.appearance.blendMode", defaultValue: "Blend mode"),
                            isChanged: style.backgroundBlendMode != Personalization().backgroundBlendMode) {
                    Picker("", selection: styleBinding(\.backgroundBlendMode)) {
                        ForEach(UI.Theme.ColorBlendMode.allCases) { mode in
                            Text(mode.localizedDisplayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        } header: {
            Text(AppText.string("settings.appearance.defaultImageCardStyle", defaultValue: "Default image card style"))
        } footer: {
            Text(AppText.string("settings.appearance.defaultImageCardStyle.footer", defaultValue: "When on, image groups, image rows, and containers without their own style inherit this design. Specific image, image-group, tag, and container styles remain local overrides above this default."))
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
