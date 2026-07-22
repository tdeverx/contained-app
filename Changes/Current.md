# Faster, smoother navigation

- Made the experimental toolbar-first interface more responsive at idle and while moving between pages by removing persistent-data work from navigation controls.
- Improved container-grid scrolling, grouping, resizing, and card transitions with lighter compact graphs and less layout work during rendering.
- Made Activity, container History, and Logs faster to open and switch between by using bounded caches, cancellable history loads, and stable batched console updates.
- Reduced background refresh overhead by skipping unchanged inventory writes and preparing only containers whose stored details actually changed.
- Expanded SwiftPM and native Xcode coverage for these performance paths and documented repeatable Instruments checks for future regressions.
