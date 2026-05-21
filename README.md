# HTML Editor

A lightweight macOS HTML editor built with **SwiftUI**, **AppKit**, and **WebKit**.
It provides a split-view editing experience with a syntax-highlighted, multi-tab
code editor and a live, dark-mode-aware preview.

## Features

- **Multi-tab document support**
  - Open multiple HTML files in a single window
  - Tab strip with per-tab titles, hover-to-close, and a `+` button
  - Each tab remembers its own cursor/selection
  - `⌘T` new tab, `⌘W` close tab

- **Split editor + preview layout**
  - Edit HTML on the left, see rendered output on the right
  - Live preview rendered in a `WKWebView`, updated after a short debounce

- **Dark-mode-aware preview**
  - The preview follows the system appearance (`color-scheme: light dark`)
    instead of forcing a white background, so pages that don't set their own
    colors render correctly in dark mode

- **Line numbers**
  - A gutter draws 1-based line numbers next to the editor
  - Wrapped lines share a single number (standard editor behavior)

- **Find & replace** (`⌘F`)
  - Next/previous navigation with match counts ("3 of 12")
  - Case-sensitive, whole-word, and regular-expression options
  - Replace and Replace All
  - The current selection pre-fills the search field

- **Tab / indent support**
  - `Tab` indents the selected lines (or inserts a 2-space soft tab)
  - `Shift-Tab` outdents
  - `Return` keeps the current indentation and adds one level after an
    opening tag or `{`

- **HTML formatting / prettify** (`⌥⌘F`)
  - Re-indents the document with consistent 2-space nesting
  - Preserves the contents of `<pre>`, `<textarea>`, `<script>`, and `<style>`

- **Syntax highlighting for HTML, CSS, and JavaScript**
  - HTML: tags, attributes, string values, comments, `<!DOCTYPE>`
  - CSS (inside `<style>`): selectors, properties, values, comments
  - JavaScript (inside `<script>`): keywords, strings, numbers, comments
  - Colors are dynamic and stay legible in both light and dark mode

- **Export options**
  - Standalone HTML (wraps a fragment in a complete document if needed)
  - Minified HTML
  - PDF (rendered from the live preview)

- **Toolbar shortcuts for common markup**
  - Headings `H1`–`H3`; inline bold, italic, code; link, image, lists, paragraph
  - Format, Find, and Export actions

- **Status bar**
  - Current file path and cursor line/column

## Built With

Swift · SwiftUI · AppKit · WebKit · Xcode

## Architecture

The editor's logic is separated from its AppKit/SwiftUI presentation so the core
behavior can be unit-tested without a running app or a Mac display.

```text
html-editor/
├── Package.swift                 # Builds HTMLEditorCore + tests via SwiftPM
├── HTMLEditor/
│   ├── HTMLEditor.xcodeproj
│   └── HTMLEditor/
│       ├── HtmlEditorApp.swift   # App entry point, menu commands
│       ├── ContentView.swift     # Window layout, toolbar, export actions
│       ├── Workspace.swift        # Open tabs + active-tab tracking
│       ├── DocumentModel.swift    # Per-document text, file I/O, cursor
│       ├── TabBarView.swift       # Tab strip
│       ├── FindBar.swift          # Find/replace UI + state
│       ├── EditorView.swift       # NSTextView wrapper (editing, indent keys)
│       ├── LineNumberRulerView.swift  # Line-number gutter
│       ├── HTMLSyntaxHighlighter.swift # Maps tokens → text attributes
│       ├── EditorTheme.swift      # Light/dark color palette
│       ├── PreviewView.swift      # WKWebView wrapper (debounced preview)
│       ├── ExportActions.swift    # Save panels + PDF rendering for export
│       ├── TextViewStore.swift    # Bridge from UI actions to the live text view
│       └── Core/                  # Pure, Foundation-only, unit-tested logic
│           ├── SyntaxTokenizer.swift   # HTML/CSS/JS tokenizer
│           ├── TextEditingOps.swift    # Tab/indent/newline transforms
│           ├── FindEngine.swift        # Search / replace
│           ├── HTMLFormatter.swift     # Prettify
│           ├── HTMLExporter.swift      # Minify / standalone / filename
│           └── TextMetrics.swift       # Line/column math
└── Tests/HTMLEditorCoreTests/     # XCTest suite for everything in Core/
```

Everything in `Core/` imports only `Foundation`, has no UI dependencies, and is
covered by tests. The AppKit/SwiftUI layer is a thin shell that wires those
functions to the editor.

## Requirements

- macOS (recent; the project targets a current deployment SDK)
- Xcode
- WebKit framework (already referenced by the project)

## Getting Started

Open the Xcode project and run:

```text
HTMLEditor/HTMLEditor.xcodeproj
```

1. Open the project in Xcode
2. Select the **HTMLEditor** target
3. Build and run with **⌘R**

If you are setting the project up from scratch, see `SETUP.md`.

## Running the Tests

The pure logic in `Core/` is exercised by an XCTest suite via Swift Package
Manager — no app build or display required:

```bash
swift test
```

Or open `Package.swift` in Xcode and press **⌘U**. (The same `Core/` files are
compiled both by the app target and by the `HTMLEditorCore` package library, so
the tests validate exactly the code the app runs.)

## Keyboard Shortcuts

| Action            | Shortcut |
|-------------------|----------|
| New tab           | `⌘T`     |
| Open (new tab)    | `⌘O`     |
| Close tab         | `⌘W`     |
| Save              | `⌘S`     |
| Save As           | `⇧⌘S`    |
| Find & replace    | `⌘F`     |
| Format / prettify | `⌥⌘F`    |
| Indent / outdent  | `Tab` / `⇧Tab` |

## Notes & Caveats

- **Indent, Return, and Format** apply their change by replacing the whole
  document in a single undoable edit. This keeps the implementation simple and
  fully undoable; for very large documents the rewrite is heavier than a
  localized edit.
- **Undo history is per text view.** Switching tabs recreates the editor for the
  newly active document, so the undo stack does not carry across a tab switch
  (cursor/selection are preserved).
- **Syntax highlighting is tokenizer-based**, not a full parser. It handles the
  common cases (including embedded CSS/JS) well and is intentionally lightweight.
- The line-number gutter aligns numbers to each logical line's first fragment;
  unusual layouts may show minor alignment quirks.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
