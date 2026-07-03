import SwiftUI

/// Root namespace for Contained's reusable visual system.
public enum UI {}

public extension UI {
    enum Card {}
    enum Panel {}
    enum Toolbar {}
    enum Control {}
    enum Action {}
    enum Command {}
    enum Copy {}
    enum State {}
    enum Symbol {}
    enum Chart {}
    enum List {}
    enum Surface {}
    enum Theme {}
    enum Badge {}
    enum Form {}
    enum Layout {}
    enum Console {}
    enum MenuBar {}
}

public extension UI {
/// Minimal raw tokens shared by the visual system.
///
/// Prefer contextual routes such as `UI.Panel.Padding.top` or
/// `UI.Card.Radius.container` from app code. Raw tokens stay here so package
/// elements can mirror the same primitive defaults without duplicating values.
enum Tokens {
    public enum Radius {
        /// Radius delta between nested glass levels: sheet -> card -> control -> key cap.
        public static let step: CGFloat = 6
        public static let control: CGFloat = 10
        public static let card: CGFloat = 16
        public static let sheet: CGFloat = 22
        public static let keyCap: CGFloat = control - step
        public static let iconChip: CGFloat = control

        /// Radius for a shape inset inside a parent with the same corner center.
        public static func inset(from outer: CGFloat, by inset: CGFloat) -> CGFloat {
            max(0, outer - inset)
        }
    }

    public enum Space {
        public static let hairline: CGFloat = 1
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum CardSize {
        // Generous max widths so the adaptive grid stretches the fitted columns to fill the row,
        // rather than capping them tightly and leaving trailing dead space on wide windows.
        public static let compactMin: CGFloat = 230
        public static let compactMax: CGFloat = 400
        public static let largeMin: CGFloat = 300
        public static let largeMax: CGFloat = 520
    }

    /// Canonical sheet dimensions — expose through `UI.Panel.SheetSize` for app and UX use. Replaces ad-hoc
    /// `width:height:` literals so every sheet snaps to one of a few sizes.
    public enum SheetSize {
        public static let small = CGSize(width: 420, height: 280)    // confirmations, short forms
        public static let form = CGSize(width: 560, height: 680)     // the run/edit form
        public static let console = CGSize(width: 560, height: 540)  // streamed-progress / logs
        public static let inspector = CGSize(width: 600, height: 560) // Dense detail/history pages
        public static let releaseNotes = CGSize(width: 620, height: 520)
        public static let wide = CGSize(width: 720, height: 560)     // build workspace
        public static let dialogWidth: CGFloat = 460
    }

    /// Morph-panel dimensions shared by toolbar origins and panel content.
    public enum PanelSize {
        // Global floor applied in UX.Morph.Geometry.fittedSize — panels never shrink below these or exceed
        // the available window area (handled separately via margin clamping). The height floor is tiny
        // so content-hugging panels can collapse close to their header when there's little to show.
        public static let minWidth: CGFloat = 300
        public static let minHeight: CGFloat = 50

        public static let add = CGSize(width: 440, height: 300)
        public static let palette = CGSize(width: 560, height: 480)
        public static let updatesOrigin = CGSize(width: 440, height: 300)
        public static let images = CGSize(width: 520, height: 520)
        public static let imageDetail = CGSize(width: 560, height: 520)
        public static let imageTag = CGSize(width: 560, height: 360)
        public static let activityOrigin = CGSize(width: 460, height: 360)
        public static let activity = CGSize(width: 560, height: 520)
        public static let templatesOrigin = CGSize(width: 440, height: 300)
        public static let templates = CGSize(width: 460, height: 480)
        public static let system = CGSize(width: 580, height: 600)
        public static let settings = CGSize(width: 560, height: 560)
    }

    /// Icon-button / chip dimensions used across menus and headers.
    public enum IconSize {
        public static let statusDot: CGFloat = 8
        public static let serviceDot: CGFloat = 9
        public static let rowIconColumn: CGFloat = 20
        public static let rowMenu: CGFloat = 22   // ellipsis row menus
        public static let control: CGFloat = 28   // sheet-header circle buttons
        public static let chip: CGFloat = 30      // small status chips
        public static let headerChip: CGFloat = 34 // detail-header chips
        public static let appIcon: CGFloat = 56
    }

    /// Fixed widths for compact form controls where stable alignment matters more than fluid sizing.
    public enum FormWidth {
        public static let shortReadout: CGFloat = 44
        public static let memoryReadout: CGFloat = 64
        public static let port: CGFloat = 70
        public static let containerPort: CGFloat = 80
        public static let userID: CGFloat = 90
        public static let shellPicker: CGFloat = 140
        public static let compactSlider: CGFloat = 140
        public static let networkName: CGFloat = 180
        public static let tintColorHex: CGFloat = 220
        public static let refreshReadout: CGFloat = 32
    }

    public enum Card {
        public static let padding: CGFloat = 10
        public static let compactTextSpacing: CGFloat = Space.hairline
        public static let detailTextSpacing: CGFloat = Space.xxs
        public static let footerDividerHeight: CGFloat = Space.l
        public static let sparklineHeight: CGFloat = 58
        public static let iconBackgroundOpacity: Double = 0.16
        public static let iconSelectedBackgroundOpacity: Double = 0.24
        public static let iconEmphasisBackgroundOpacity: Double = 0.22
        public static let plainFillOpacity: Double = 0.18
        public static let selectedSubtleFillOpacity: Double = 0.10
        public static let selectedResourceFillOpacity: Double = 0.12
        public static let selectedTintFillOpacity: Double = 0.18
        public static let selectedPersonalizedFillOpacity: Double = 0.14
    }

    public enum Chart {
        public static let height: CGFloat = 140
        public static let axisDesiredCount = 4
        public static let areaOpacity: Double = 0.30
        public static let emptyHeight: CGFloat = 200
    }

    public enum Badge {
        public static let compactHorizontalPadding: CGFloat = 7
        public static let horizontalPadding: CGFloat = Space.s
        public static let verticalPadding: CGFloat = Space.xxs
        public static let scopeVerticalPadding: CGFloat = 3
        public static let accentOpacity: Double = 0.16
        public static let statusOpacity: Double = 0.14
    }

    public enum Keyboard {
        public static let keyHorizontalPadding: CGFloat = 5
        public static let keyVerticalPadding: CGFloat = Space.xxs
    }

    public enum Terminal {
        public static let surfaceOpacity: Double = 0.22
        public static let nativeBackgroundOpacity: CGFloat = 0.82
        public static let nativeForegroundWhite: CGFloat = 0.92
        public static let fontSize: CGFloat = 12
    }

    public enum InlineControl {
        public static let gradientDial: CGFloat = 36
        public static let gradientReadout: CGFloat = 40
        public static let gradientKnob: CGFloat = 7
        public static let gradientKnobInset: CGFloat = Space.xs
        public static let gradientStrokeOpacity: Double = 0.4
        public static let subtleTileOpacity: Double = 0.25
    }

    public enum MenuBar {
        public static let width: CGFloat = 340
        public static let titleWidth: CGFloat = 78
        public static let padding: CGFloat = 14
    }

    /// The app toolbar band — custom (non-native) controls sized to macOS 26 Liquid Glass toolbar
    /// proportions (tuned against Finder). `controlHeight` is shared by every band element (glass
    /// button groups and the search field) so they align on one baseline; `groupRadius` is the
    /// concentric capsule for them. Glyphs are a touch smaller than the capsule with horizontal glass
    /// padding around them, matching the airy native look.
    public enum Toolbar {
        // Exact spec: controls are 36pt tall (length hugs content), with 8pt of padding around the band
        // (horizontal, top — matched below — and between groups), so the band is 8 + 36 + 8 = 52.
        public static let band: CGFloat = 52           // title-bar band height
        public static let controlHeight: CGFloat = 36  // glass groups + search field share this height
        // Button glyphs use `.headline` + `.imageScale(.large)` (see ToolbarControls) so they scale
        // with Dynamic Type — no fixed point size token.
        public static let iconInnerPadding: CGFloat = 4 // padding around the glyph inside the 28 item
        public static let buttonItemHeight: CGFloat = 28
        public static var iconContentWidth: CGFloat { buttonItemHeight - iconInnerPadding * 2 }
        public static var statusLabelTrailingPadding: CGFloat { iconInnerPadding * 2 }
        public static let buttonGroupHeight: CGFloat = 36
        public static let outerPadding: CGFloat = 8    // band inset from the window edges
        // Space reserved when custom toolbar chrome needs to mirror the traffic-light cluster.
        public static let leadingInset: CGFloat = 80
        public static let trafficLightsWidth: CGFloat = 82 // close/min/zoom cluster width for reserved toolbar slots
        public static let groupPaddingH: CGFloat = 0   // horizontal glass margin inside a group
        public static let groupSpacing: CGFloat = 8    // spacing between buttons / groups
        public static let searchMaxWidth: CGFloat = 380
        // Search field internals.
        public static let searchInnerPadding: CGFloat = iconInnerPadding * 2 // matches glass button edge inset
        public static let searchIconGap: CGFloat = 6       // gap between icon and text
        public static let searchOpenHeaderHeight: CGFloat = 48 // taller header row once the palette expands
        // The search icon + text use the semantic `.body` style (13pt on macOS; text adds medium weight),
        // so they scale with Dynamic Type — no fixed point size tokens.
        /// Padding above the controls (and matched below) — the controls sit on the native toolbar line.
        public static let topPadding: CGFloat = 8
        public static var groupRadius: CGFloat { controlHeight / 2 }  // concentric capsule
    }
}
}

public extension UI.Panel {
    /// Panel padding mirrors the global spacing scale so all panel chrome can diverge in one place.
    enum Padding {
        public static let top = UI.Layout.Spacing.l
        public static let bottom = UI.Layout.Spacing.l
        public static let leading = UI.Layout.Spacing.l
        public static let trailing = UI.Layout.Spacing.l
        public static let all = UI.Layout.Spacing.l
        public static let compact = UI.Layout.Spacing.s
    }

    /// Panel spacing mirrors the global spacing scale used by stacked sections and rows.
    enum Spacing {
        public static let row = UI.Layout.Spacing.m
        public static let section = UI.Layout.Spacing.l
        public static let compact = UI.Layout.Spacing.s
        public static let hairline = UI.Layout.Spacing.hairline
    }

    /// Panel radii mirror the global sheet radius because floating panels share the sheet silhouette.
    enum Radius {
        public static let surface = UI.Tokens.Radius.sheet
    }

    /// Panel and sheet sizes mirror the raw size defaults used by morph targets.
    enum Size {
        public static let minWidth = UI.Tokens.PanelSize.minWidth
        public static let minHeight = UI.Tokens.PanelSize.minHeight
        public static let add = UI.Tokens.PanelSize.add
        public static let palette = UI.Tokens.PanelSize.palette
        public static let updatesOrigin = UI.Tokens.PanelSize.updatesOrigin
        public static let images = UI.Tokens.PanelSize.images
        public static let imageDetail = UI.Tokens.PanelSize.imageDetail
        public static let imageTag = UI.Tokens.PanelSize.imageTag
        public static let activityOrigin = UI.Tokens.PanelSize.activityOrigin
        public static let activity = UI.Tokens.PanelSize.activity
        public static let templatesOrigin = UI.Tokens.PanelSize.templatesOrigin
        public static let templates = UI.Tokens.PanelSize.templates
        public static let system = UI.Tokens.PanelSize.system
        public static let settings = UI.Tokens.PanelSize.settings
    }

    /// Modal sheet sizes mirror the raw canonical sheet dimensions.
    enum SheetSize {
        public static let small = UI.Tokens.SheetSize.small
        public static let form = UI.Tokens.SheetSize.form
        public static let console = UI.Tokens.SheetSize.console
        public static let inspector = UI.Tokens.SheetSize.inspector
        public static let releaseNotes = UI.Tokens.SheetSize.releaseNotes
        public static let wide = UI.Tokens.SheetSize.wide
        public static let dialogWidth = UI.Tokens.SheetSize.dialogWidth
    }
}

public extension UI.Card {
    /// Card padding mirrors the compact card rhythm. The raw value is intentionally denser than
    /// panel padding so compact cards keep their existing content-hugging silhouette.
    enum Padding {
        public static let content = UI.Tokens.Card.padding
        public static let body = UI.Layout.Spacing.s
        public static let widget = UI.Tokens.Card.padding
    }

    /// Card spacing mirrors compact card internals and footer/widget grouping.
    enum Spacing {
        public static let compactText = UI.Tokens.Card.compactTextSpacing
        public static let detailText = UI.Tokens.Card.detailTextSpacing
        public static let footer = UI.Tokens.Card.padding
        public static let widget = UI.Tokens.Card.padding
    }

    /// Card radii mirror raw radius defaults. Expanded cards intentionally use the sheet radius.
    enum Radius {
        public static let container = UI.Tokens.Radius.card
        public static let expanded = UI.Tokens.Radius.sheet
        public static let control = UI.Tokens.Radius.control
    }

    /// Card metrics mirror repeated card chrome values.
    enum Metric {
        public static let footerDividerHeight = UI.Tokens.Card.footerDividerHeight
        public static let sparklineHeight = UI.Tokens.Card.sparklineHeight
        public static let iconBackgroundOpacity = UI.Tokens.Card.iconBackgroundOpacity
        public static let iconSelectedBackgroundOpacity = UI.Tokens.Card.iconSelectedBackgroundOpacity
        public static let iconEmphasisBackgroundOpacity = UI.Tokens.Card.iconEmphasisBackgroundOpacity
        public static let plainFillOpacity = UI.Tokens.Card.plainFillOpacity
        public static let selectedSubtleFillOpacity = UI.Tokens.Card.selectedSubtleFillOpacity
        public static let selectedResourceFillOpacity = UI.Tokens.Card.selectedResourceFillOpacity
        public static let selectedTintFillOpacity = UI.Tokens.Card.selectedTintFillOpacity
        public static let selectedPersonalizedFillOpacity = UI.Tokens.Card.selectedPersonalizedFillOpacity
    }

    /// Card grid sizing mirrors adaptive grid defaults for repeated card collections.
    enum Grid {
        public static let compactMin = UI.Tokens.CardSize.compactMin
        public static let compactMax = UI.Tokens.CardSize.compactMax
        public static let largeMin = UI.Tokens.CardSize.largeMin
        public static let largeMax = UI.Tokens.CardSize.largeMax
    }
}

public extension UI.Toolbar {
    /// Toolbar sizing mirrors the macOS Liquid Glass toolbar rhythm.
    enum Size {
        public static let band = UI.Tokens.Toolbar.band
        public static let controlHeight = UI.Tokens.Toolbar.controlHeight
        public static let buttonItemHeight = UI.Tokens.Toolbar.buttonItemHeight
        public static let buttonGroupHeight = UI.Tokens.Toolbar.buttonGroupHeight
        public static let searchMaxWidth = UI.Tokens.Toolbar.searchMaxWidth
        public static let searchOpenHeaderHeight = UI.Tokens.Toolbar.searchOpenHeaderHeight
        public static var iconContentWidth: CGFloat { UI.Tokens.Toolbar.iconContentWidth }
        public static var groupRadius: CGFloat { UI.Tokens.Toolbar.groupRadius }
    }

    /// Toolbar spacing mirrors the raw toolbar band spacing.
    enum Spacing {
        public static let outerPadding = UI.Tokens.Toolbar.outerPadding
        public static let groupSpacing = UI.Tokens.Toolbar.groupSpacing
        public static let groupPaddingH = UI.Tokens.Toolbar.groupPaddingH
        public static let searchIconGap = UI.Tokens.Toolbar.searchIconGap
        public static let searchInnerPadding = UI.Tokens.Toolbar.searchInnerPadding
        public static let iconInnerPadding = UI.Tokens.Toolbar.iconInnerPadding
        public static let topPadding = UI.Tokens.Toolbar.topPadding
    }

    /// Toolbar placement values mirror traffic-light-aware raw defaults.
    enum Placement {
        public static let leadingInset = UI.Tokens.Toolbar.leadingInset
        public static let trafficLightsWidth = UI.Tokens.Toolbar.trafficLightsWidth
        public static var statusLabelTrailingPadding: CGFloat { UI.Tokens.Toolbar.statusLabelTrailingPadding }
    }
}

public extension UI.Chart {
    /// Chart sizing mirrors compact and expanded chart defaults.
    enum Size {
        public static let height = UI.Tokens.Chart.height
        public static let emptyHeight = UI.Tokens.Chart.emptyHeight
    }

    /// Chart rendering mirrors reusable chart defaults.
    enum Rendering {
        public static let axisDesiredCount = UI.Tokens.Chart.axisDesiredCount
        public static let areaOpacity = UI.Tokens.Chart.areaOpacity
    }
}

public extension UI.Badge {
    /// Badge padding mirrors repeated capsule label defaults.
    enum Padding {
        public static let compactHorizontal = UI.Tokens.Badge.compactHorizontalPadding
        public static let horizontal = UI.Tokens.Badge.horizontalPadding
        public static let vertical = UI.Tokens.Badge.verticalPadding
        public static let scopeVertical = UI.Tokens.Badge.scopeVerticalPadding
    }

    /// Badge opacity mirrors reusable status/accent fill defaults.
    enum Opacity {
        public static let accent = UI.Tokens.Badge.accentOpacity
        public static let status = UI.Tokens.Badge.statusOpacity
    }
}

public extension UI.Form {
    /// Form widths mirror fixed-width controls used for stable alignment.
    enum Width {
        public static let shortReadout = UI.Tokens.FormWidth.shortReadout
        public static let memoryReadout = UI.Tokens.FormWidth.memoryReadout
        public static let port = UI.Tokens.FormWidth.port
        public static let containerPort = UI.Tokens.FormWidth.containerPort
        public static let userID = UI.Tokens.FormWidth.userID
        public static let shellPicker = UI.Tokens.FormWidth.shellPicker
        public static let compactSlider = UI.Tokens.FormWidth.compactSlider
        public static let networkName = UI.Tokens.FormWidth.networkName
        public static let tintColorHex = UI.Tokens.FormWidth.tintColorHex
        public static let refreshReadout = UI.Tokens.FormWidth.refreshReadout
    }
}

public extension UI.Layout {
    /// Generic layout spacing mirrors the raw spacing scale for app composition with no element owner.
    enum Spacing {
        public static let hairline = UI.Tokens.Space.hairline
        public static let xxs = UI.Tokens.Space.xxs
        public static let xs = UI.Tokens.Space.xs
        public static let s = UI.Tokens.Space.s
        public static let m = UI.Tokens.Space.m
        public static let l = UI.Tokens.Space.l
        public static let xl = UI.Tokens.Space.xl
        public static let xxl = UI.Tokens.Space.xxl
    }
}

public extension UI.Control {
    /// Control sizing mirrors reusable icon/control defaults.
    enum Size {
        public static let statusDot = UI.Tokens.IconSize.statusDot
        public static let serviceDot = UI.Tokens.IconSize.serviceDot
        public static let rowIconColumn = UI.Tokens.IconSize.rowIconColumn
        public static let rowMenu = UI.Tokens.IconSize.rowMenu
        public static let control = UI.Tokens.IconSize.control
        public static let chip = UI.Tokens.IconSize.chip
        public static let headerChip = UI.Tokens.IconSize.headerChip
        public static let appIcon = UI.Tokens.IconSize.appIcon
    }

    /// Inline-control sizing mirrors repeated compact editor defaults.
    enum InlineSize {
        public static let gradientDial = UI.Tokens.InlineControl.gradientDial
        public static let gradientReadout = UI.Tokens.InlineControl.gradientReadout
        public static let gradientKnob = UI.Tokens.InlineControl.gradientKnob
        public static let gradientKnobInset = UI.Tokens.InlineControl.gradientKnobInset
    }

    /// Inline-control opacity mirrors repeated compact editor defaults.
    enum Opacity {
        public static let gradientStroke = UI.Tokens.InlineControl.gradientStrokeOpacity
        public static let subtleTile = UI.Tokens.InlineControl.subtleTileOpacity
    }
}

public extension UI.Console {
    /// Console metrics mirror terminal surface defaults.
    enum Metric {
        public static let surfaceOpacity = UI.Tokens.Terminal.surfaceOpacity
        public static let nativeBackgroundOpacity = UI.Tokens.Terminal.nativeBackgroundOpacity
        public static let nativeForegroundWhite = UI.Tokens.Terminal.nativeForegroundWhite
        public static let fontSize = UI.Tokens.Terminal.fontSize
    }
}

public extension UI.MenuBar {
    /// Menu-bar dimensions mirror the compact popover defaults.
    enum Size {
        public static let width = UI.Tokens.MenuBar.width
        public static let titleWidth = UI.Tokens.MenuBar.titleWidth
    }

    /// Menu-bar padding mirrors the compact popover inset.
    enum Padding {
        public static let all = UI.Tokens.MenuBar.padding
    }
}

public extension View {
    /// Apply a canonical sheet size from `UI.Panel.SheetSize`.
    func frame(_ size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}
