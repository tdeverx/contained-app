## Changed

- Routed design-system and navigation package copy through app-supplied strings so reusable packages stay language-light while the app is ready for English-only localization support.
- Added a display-neutral package error contract so Core/Runtime throw typed codes and context while the app owns localized error messages, alerts, and Activity entries.
