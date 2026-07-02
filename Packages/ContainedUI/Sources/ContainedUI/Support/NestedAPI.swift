import SwiftUI

public extension UI.Card {
    typealias Scaffold = CardScaffold
    typealias Size = CardSize
    typealias Density = CardDensity
    typealias SizePicker = CardSizePicker
    typealias TextStyle = CardTextStyle
    typealias NoPage = CardNoPage
    typealias Pages = CardPages
    typealias Page = CardPage
    typealias InsetSection = CardInsetSection
    typealias FooterChip = CardFooterChip
    typealias FooterButton = CardFooterButton
    typealias FooterGroup = CardFooterGroup
    typealias FooterMini = CardFooterMini
    typealias WidgetGroup = CardWidgetGroup
    typealias IconChip = CardIconChip
    typealias MetricText = CardMetricText
    typealias TitleText = CardTitleText
    typealias SubtitleText = CardSubtitleText
    typealias MonospacedTitleText = CardMonospacedTitleText
    typealias MonospacedSubtitleText = CardMonospacedSubtitleText
}

public extension UI.Panel {
    typealias Scaffold = PanelScaffold
    typealias PageScaffold = ContainedUI.PageScaffold
    typealias Header = PanelTitleBar
    typealias SheetTitleBar = PanelSheetTitleBar
    typealias Section = PanelSectionView
    typealias Row = PanelRowView
    typealias ToggleRow = PanelToggleRowView
    typealias Field = PanelFieldView
}

public extension UI.Action {
    typealias Item = ActionItem
    typealias Group = ActionGroup
    typealias Cluster = ActionCluster
    typealias Items = ActionItems
    typealias MenuLabel = ActionMenuLabel
    typealias ProgressCapsule = ActionProgressCapsule
    typealias TextButton = ActionTextButton
    typealias TextProminence = ActionTextProminence
    typealias ToggleButton = ActionToggleButton
    typealias SelectionBar = ActionSelectionBar
}

public extension UI.Control {
    typealias InputCluster = ContainedUI.InputCluster
    typealias OptionStack = ContainedUI.OptionStack
    typealias OptionTile = ContainedUI.OptionTile
    typealias RowMenu = ContainedUI.RowMenu
    typealias SearchField = ContainedUI.SearchField
    typealias MenuButton = ContainedUI.MenuButton
    typealias GradientAngle = GradientAngleControl
    typealias TintSwatch = ContainedUI.TintSwatch
}

public extension UI.Toolbar {
    typealias SearchField = ToolbarSearchField
    typealias VanitySlot = ToolbarVanitySlot
    typealias StatusButton = ToolbarStatusButton
    typealias ActionCluster = ToolbarActionCluster
    typealias MenuButton = ToolbarMenuButton
    typealias TitleSubtitle = ToolbarTitleSubtitle
}

public extension UI.Command {
    typealias Preview = PreviewBar
}

public extension UI.Chart {
    typealias Style = ChartStyle
    typealias GraphStyle = ContainedUI.GraphStyle
    typealias Interpolation = WidgetInterpolation
    typealias Scale = SparklineScale
    typealias Sparkline = SparklineView
    typealias MetricTile = SparklineMetricTile
    typealias SampleBuffer = ContainedUI.SampleBuffer
}

public extension UI.Surface {
    typealias Content = ContentSurface
    typealias Input = InputSurface
}

public extension UI.State {
    typealias Tone = StateTone
    typealias StatusText = ContainedUI.StatusText
    typealias Empty = EmptyState
    typealias Hero = HeroState
    typealias Loading = LoadingState
    typealias ProgressIndicator = ContainedUI.ProgressIndicator
    typealias SectionLabel = ContainedUI.SectionLabel
    typealias InlineStatus = ContainedUI.InlineStatus
    typealias ErrorBanner = ErrorBannerView
    typealias Banner = StatusBanner
    typealias ActivityStatus = ContainedUI.ActivityStatus
    typealias ActivityStatusIndicator = ContainedUI.ActivityStatusIndicator
}

public extension UI.Symbol {
    typealias Size = SymbolSize
    typealias Image = SymbolView
}

public extension UI.List {
    typealias Stack = ListStack
    typealias Section = ListSection
    typealias Row = ListRow
    typealias RowChevron = ListRowChevron
    typealias MetadataRow = ContainedUI.MetadataRow
    typealias MetadataBadgeRow = ContainedUI.MetadataBadgeRow
    typealias KeyValueRow = ContainedUI.KeyValueRow
    typealias CompactInfoRow = ContainedUI.CompactInfoRow
}

public extension UI.Badge {
    typealias Text = BadgeText
    typealias Status = StatusBadge
    typealias Dot = StatusDot
    typealias ScopeLabel = ScopeChipLabel
}

public extension UI.Theme {
    typealias Tint = ThemeTint
    typealias Material = ThemeMaterial
    typealias WindowMaterial = ThemeWindowMaterial
    typealias Appearance = ThemeAppearanceMode
    typealias ColorBlendMode = ThemeColorBlendMode
    typealias ButtonTintStyle = ContainedUI.ButtonTintStyle
    typealias BackgroundLayer = ContentBackgroundLayer
}

public extension UI.Control {
    typealias KeyCap = ContainedUI.KeyCap
    typealias KeyboardHint = ContainedUI.KeyboardHint
    typealias MetricTile = ContainedUI.MetricTile
}
