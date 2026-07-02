# Localization

Contained is English-only for now, but app copy should already be routed through
localization-ready APIs.

## Ownership

- `Sources/Contained` owns all user-facing strings and the localization catalog.
- `ContainedDesignSystem` and `ContainedNavigation` are building-block packages:
  they own structure and visuals, not app copy.
- `ContainedCore`, `ContainedRuntime`, and runtime adapters should stay
  language-free except for stable technical identifiers, raw values, and command
  output.

If a package component needs visible text, add an explicit parameter instead of
adding an English default in the package. Examples include action help, close
labels, search clear labels, page-control titles, selection-count text, and
color/tint display names.

Package failures follow the same ownership rule. Reusable targets should throw
typed errors with stable codes/context, usually by conforming to
`ContainedPackageError`. The app maps those errors through
`AppErrorPresentation` and `AppText`, then decides whether to show a toast,
inline error, alert, or Activity entry. Do not attempt to localize arbitrary
backend stderr; preserve it as runtime-provided detail unless an adapter can map
it to a known typed case.

## App Strings

Use `AppText` for reusable app-owned labels and dynamic templates:

```swift
DesignToolbarSearchField(text: $query,
                         prompt: "Search this page",
                         clearSearchLabel: AppText.clearSearch,
                         focused: $focused,
                         onClear: { query = "" }) {
    EmptyView()
}

TintSelector(selection: $settings.accentTint) {
    $0.localizedDisplayName
}

DesignSelectionActionBar(count: selection.count,
                         countLabel: AppText.selectedCount,
                         actions: actions)

do {
    try await runtime.performSystemAction("start")
} catch {
    app.flash(error.appDisplayMessage)
    app.logger.recordFailure("Start service failed",
                             error: error,
                             category: .system)
}
```

Plain SwiftUI literals such as `Text("Settings")`, `Button("Refresh")`, and
`Label("Logs", systemImage: "text.alignleft")` remain localization-ready through
SwiftUI. Strings that are passed into package `String` parameters, generated
dynamically, used as accessibility labels, or exposed as enum display names
should go through `AppText` or an app-side localized display extension.

## English-Only Baseline

The root package declares `defaultLocalization: "en"` and the app carries
`Sources/Contained/Resources/Localizable.xcstrings`. English currently comes
from `String(localized:defaultValue:bundle:)` fallbacks in app code. Future
translations can fill the string catalog without changing package APIs.
