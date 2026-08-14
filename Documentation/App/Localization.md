# Localization

Contained is English-only for now, but app copy should already be routed through
localization-ready APIs.

## Ownership

- `Sources/ContainedApp` owns product-facing strings and the app localization catalog.
- `ContainedUI` and `ContainedUX` are building-block packages:
  they own structure and visuals, not app copy.
- `ContainedCore` owns display-neutral semantic localization where the backend
  needs to stand alone: schema labels/help, validation messages, runtime
  capability reasons, Compose/projection warnings, and package-error fallback
  descriptions. Its localization APIs support downstream override/wrap behavior.

If a package component needs visible text, add an explicit parameter instead of
adding an English default in the package. Examples include action help, close
labels, search clear labels, page-control titles, selection-count text, and
color/tint display names.

Package failures follow the same ownership rule. Reusable targets should throw
typed errors with stable codes/context, usually by conforming to
`Core.Error.PackageError`. Core may provide display-neutral fallback
descriptions for those codes. The app maps errors through `AppErrorPresentation`
and `AppText`, then decides whether to show a toast, inline error, alert, or
Activity entry. Do not attempt to localize arbitrary backend stderr; preserve it
for immediate runtime-detail presentation unless an adapter can map it to a known
typed case. Do not persist that detail in Activity or emit it publicly to Console.

## App Strings

Use `AppText` for reusable app-owned labels and dynamic templates:

```swift
UI.Toolbar.SearchField(text: $query,
                         prompt: "Search this page",
                         clearSearchLabel: AppText.clearSearch,
                         focused: $focused,
                         onClear: { query = "" }) {
    EmptyView()
}

UI.Control.TintSelector(selection: $settings.accentTint,
                        customLabel: AppText.customHexColor) {
    $0.localizedDisplayName
}

UI.Action.SelectionBar(count: selection.count,
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
`Sources/ContainedApp/Resources/Localizable.xcstrings`. `ContainedCore` also
declares package resources for its semantic defaults. English currently comes
from localized resources plus `String(localized:defaultValue:bundle:)`
fallbacks. Future translations can fill the catalogs without changing package
APIs.
