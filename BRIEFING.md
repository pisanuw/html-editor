# Briefing

- Purpose: A lightweight macOS HTML editor built with SwiftUI, AppKit, and WebKit, pairing a syntax-highlighted multi-tab code editor with a live preview in a split-view window.
- Current scope: macOS app with full feature set including multi-tab support, line numbers, diff gutter markers, breadcrumb bar, minimap, find & replace, Emmet expansion, code folding, HTML/CSS/JS syntax highlighting, CSS color swatches, HTML validation, and export (HTML, minified HTML, Markdown, PDF).
- Key decisions: All 12 gap features implemented as of 2026-05-22. Built using Swift Package Manager with SwiftUI + AppKit + WebKit.
- Non-goals: Cross-platform (macOS only), no server-side features, no plugin system.
