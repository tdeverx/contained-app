### Changed

- Color selectors now lead with the inherited accent and a custom `#RRGGBB` option before SwiftUI's standard Apple color palette. Selecting custom reveals a dedicated “Custom” row using the host form's normal alignment and `#007AFF` as its example. The app-accent picker inherits the native macOS accent; other pickers inherit the selected app accent, which now scopes both native controls and explicit accent-colored selection, navigation, status, chart, and resource chrome throughout the app.
- Shared panel and form rows now move wide controls beneath their labels instead of clipping or squeezing important titles.
