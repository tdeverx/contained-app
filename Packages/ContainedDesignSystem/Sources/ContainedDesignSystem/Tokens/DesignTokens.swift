import SwiftUI

/// Design tokens — the single source of truth for spacing, radii, and type used across the app.
public enum DesignTokens {
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

    /// Canonical sheet dimensions — pass to `.frame(DesignTokens.SheetSize.form)`. Replaces ad-hoc
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
        // Global floor applied in MorphGeometry.fittedSize — panels never shrink below these or exceed
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

    public enum DesignCard {
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

public extension View {
    /// Apply a canonical sheet size from `DesignTokens.SheetSize`.
    func frame(_ size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}
