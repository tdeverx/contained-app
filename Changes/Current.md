# Performance and verification

- Reduced idle UI work by avoiding unchanged runtime-inventory writes, stopping live stats while the Containers surface is hidden, and bounding historical chart rendering.
- Removed SwiftData fetches from navigation chrome, moved Activity and container-history rows to bounded value projections, and made inventory serialization proportional to actual changes.
- Moved grid filtering/grouping off the render path, replaced compact Swift Charts with a Canvas renderer, limited morph geometry reads to the selected card, and batched both log consoles into stable bounded blocks.
- Kept SwiftPM and Xcode dependency pins aligned, expanded automated local-package coverage, and retained native Xcode result bundles in PR CI.
