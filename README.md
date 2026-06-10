# HTML Editor

[![CI](https://github.com/pisanuw/html-editor/actions/workflows/ci.yml/badge.svg)](https://github.com/pisanuw/html-editor/actions/workflows/ci.yml)

A lightweight macOS HTML editor built with **SwiftUI**, **AppKit**, and **WebKit**.
It pairs a syntax-highlighted, multi-tab code editor with a live, dark-mode-aware
preview in a single split-view window.

> Edit HTML on the left, watch it render on the right — with line numbers, a
> breadcrumb bar, find & replace, smart indentation, one-shot prettifying,
> HTML/CSS/JS highlighting, and export to standalone HTML, minified HTML,
> Markdown, or PDF.

## Features

### Editor

- **Multi-tab document support**
  - Open multiple HTML files in one window
  - Tab strip with per-tab titles, hover-to-close, and a `+` button
  - Each tab remembers its own cursor, selection, and undo stack
  - `⌘T` new tab · `⌘W` close tab · `⇧⌘T` reopen last closed tab

- **Line numbers & gutter**
  - 1-based line numbers beside the editor; wrapped lines share a single number
  - **Diff markers**: green bar = lines added since last save, orange = modified
  - **Code folding**: click the disclosure triangle to collapse/expand a tag region

- **Breadcrumb bar**
  - A strip between the find bar and editor showing the HTML element ancestry at
    the cursor — e.g. `html > body > div > p` — updated as the caret moves

- **Minimap**
  - A compact 80 px thumbnail of the entire document alongside the editor
  - Toggle via the Preview menu; the same syntax colors appear at 2 pt scale

- **Syntax highlighting for HTML, CSS, and JavaScript**
  - HTML tags, attributes, string values, comments, `<!DOCTYPE>`
  - CSS inside `<style>`: selectors, properties, values, comments
  - JavaScript inside `<script>`: keywords, strings, numbers, comments
  - **CSS color swatches**: hex colors (`#fff`, `#rrggbb`) and functional colors
    (`rgb()`, `rgba()`, `hsl()`, `hsla()`) receive a thick colored underline
    so the actual color is visible inline
  - Colors are dynamic and stay legible in both light and dark mode

- **Editing intelligence**
  - **Emmet abbreviation expansion** (`⌃E`): turn `ul>li.item$*3` into fully
    indented markup
  - **Auto-close tags**: typing `>` inserts the matching close tag and parks the
    caret between them (skips void and self-closing tags)
  - **Linked tag rename** (`⌃⌘R`): renames the opening and closing tag together
  - **Multiple cursors**: add the next occurrence (`⌘D`), split into lines
    (`⇧⌘L`), or make a column selection (`⌃⌘L`)
  - **Tag & attribute autocompletion** from caret context (Editor menu)
  - **Bracket & tag-pair match highlighting** as the caret moves
  - **Editable snippet library**: insert snippets from the Editor menu; manage
    (add / edit / delete) in a sheet, persisted across launches

- **Find & replace** (`⌘F`)
  - Next / previous with live match counts ("3 of 12")
  - Case-sensitive, whole-word, and regex options
  - Replace and Replace All
  - All matches highlighted live as you type
  - "Find across all tabs" results panel — grouped by file with line numbers

- **Go to Line** (`⌥⌘L`)
  - Type a line number to jump there instantly

- **Tab / indent support**
  - `Tab` indents selected lines (2-space soft tab)
  - `⇧Tab` outdents
  - `Return` preserves indentation and adds one level after an opening tag or `{`

- **Word wrap**
  - Toggle in Settings; when off, the editor scrolls horizontally

- **HTML formatting / prettify** (`⌥⌘F`)
  - Re-indents with consistent 2-space nesting
  - Preserves `<pre>`, `<textarea>`, `<script>`, and `<style>` contents

### Preview

- **Split editor + preview layout**
  - Source left, rendered output right, in a resizable split view
  - Live `WKWebView` preview, refreshed after a short typing debounce

- **Dark-mode-aware preview**
  - Injects `color-scheme: light dark` so pages render in dark mode when
    appropriate; pages without their own colors get a legible light background

- **Preview controls** (Preview menu)
  - Responsive / device-width presets: Phone, Tablet, Desktop
  - Live reload on/off with a manual "Reload preview" command
  - Optional scroll-position sync (editor to preview)
  - Minimap on/off toggle

### Documents & workspace

- **Multiple windows**: each window is fully independent with its own tabs
- **Session restore**: reopens the previous tabs on relaunch, including untitled
  buffers (unsaved text preserved)
- **File tree sidebar**: open a project folder to browse and open files by click
- **Auto-save** (Settings): silently saves 2 s after the last keystroke
  (files with a URL only — untitled buffers are never auto-saved)
- **External-change detection**: if a file changes on disk, a banner offers
  Reload or Ignore (the editor's own saves never trigger this)
- Recent Files menu and drag-and-drop `.html` to open

### Validation & export

- **HTML validation**: click the shield button in the status bar to run a
  structural check — missing `alt` on `<img>`, unclosed tags, unexpected closing
  tags — results listed by line with error/warning severity
- **Open in Browser** (`⌥⌘B`): writes a temp file and opens it in the default browser
- **Print** (`⌘P`): prints the rendered preview
- **Export** (File > Export)
  - Standalone HTML (wraps a fragment in a complete document when needed)
  - Minified HTML
  - Markdown (headings, emphasis, links, images, lists, code, blockquotes)
  - PDF and PNG (rendered from the live preview)

### Customization & status

- **Settings** (`⌘,`): indent width, editor font size, color theme, word wrap,
  auto-save
- **Pluggable themes**: Default, Midnight, Sepia — each light/dark aware
- **Status bar**: file path, cursor line/column, and validate button

### Performance

- Tab/Shift-Tab/Return apply localized edits (only the affected range changes)
- Per-tab undo stack, preserved across tab switches

## Built With

Swift · SwiftUI · AppKit · WebKit · Xcode

## Architecture

The editor's logic is separated from its AppKit/SwiftUI presentation so the core
behavior can be unit-tested without a running app or a Mac display.

```text
html-editor/
├── Package.swift                       # Builds HTMLEditorCore + tests via SwiftPM
├── HTMLEditor/
│   ├── HTMLEditor.xcodeproj
│   └── HTMLEditor/
│       ├── HtmlEditorApp.swift         # App entry point, multi-window, menu commands
│       ├── ContentView.swift           # Window layout, toolbar, sidebar, breadcrumb
│       ├── Workspace.swift             # Open tabs, session restore, recent files
│       ├── DocumentModel.swift         # Per-document text, file I/O, cursor, diff state
│       ├── TabBarView.swift            # Tab strip
│       ├── FindBar.swift               # Find/replace UI + state (incl. go-to-line)
│       ├── GoToLineView.swift          # Go-to-line sheet
│       ├── EditorView.swift            # NSTextView wrapper (cached per tab)
│       ├── EditorCache.swift           # Reuses each tab's text view + folding controller
│       ├── FoldingController.swift     # Code folding via glyph suppression
│       ├── FileWatcher.swift           # Dispatch-source file-change watcher
│       ├── LineNumberRulerView.swift   # Line numbers, fold triangles, diff markers
│       ├── BreadcrumbBarView.swift     # HTML element ancestry at cursor
│       ├── MinimapView.swift           # Read-only document thumbnail
│       ├── HTMLSyntaxHighlighter.swift # Token-to-attribute mapping + color swatches
│       ├── EditorTheme.swift           # Resolves the active palette to dynamic colors
│       ├── AppSettingsStore.swift      # Persists EditorSettings; pushes active theme
│       ├── SettingsView.swift          # Settings panel (indent, font, theme, wrap)
│       ├── PreviewView.swift           # WKWebView wrapper (width, live-reload, scroll)
│       ├── ExportActions.swift         # Save panels; PDF/PNG/Markdown/browser/print
│       ├── TextViewStore.swift         # Bridge from UI actions to the live NSTextView
│       ├── FindResultsView.swift       # Find-across-tabs results panel
│       ├── FileSidebarView.swift       # Project folder sidebar
│       ├── ValidationPanelView.swift   # HTML validation results sheet
│       ├── SnippetStore.swift          # UserDefaults-backed snippet persistence
│       ├── SnippetsView.swift          # Snippet management sheet
│       └── Core/                       # Pure, Foundation-only, unit-tested logic
│           ├── SyntaxTokenizer.swift   # HTML/CSS/JS tokenizer
│           ├── TextEditingOps.swift    # Tab/indent/newline transforms
│           ├── FindEngine.swift        # Search / replace
│           ├── HTMLFormatter.swift     # Prettify
│           ├── HTMLExporter.swift      # Minify / standalone / filename
│           ├── HTMLToMarkdown.swift    # HTML to Markdown conversion
│           ├── HTMLValidator.swift     # Structural HTML linting
│           ├── HTMLBreadcrumb.swift    # Element ancestry path at a character offset
│           ├── TextMetrics.swift       # Line/column math
│           ├── EmmetExpander.swift     # Emmet abbreviation to HTML
│           ├── TagEditing.swift        # Auto-close + matching-tag ranges
│           ├── MultiCursor.swift       # Next-occurrence / split / column ranges
│           ├── HTMLCompletion.swift    # Tag/attribute completion context
│           ├── CodeStructure.swift     # Bracket matching + fold regions
│           ├── FoldingModel.swift      # Hidden-range computation for folding
│           ├── MultiFileSearch.swift   # Per-document search hits (line + preview)
│           ├── PreviewWidth.swift      # Responsive / device-width presets
│           ├── EditorSettings.swift    # Indent / font / theme settings model
│           ├── ThemePalette.swift      # Named color palettes + hex parsing
│           ├── SessionState.swift      # Open-tab session + recent-files models
│           ├── Snippet.swift           # Snippet model + library codec
│           └── IDKeyedStore.swift      # Generic UUID-keyed store (backs EditorCache)
└── Tests/HTMLEditorCoreTests/          # XCTest suite for everything in Core/
    ├── SyntaxTokenizerTests.swift
    ├── TextEditingOpsTests.swift
    ├── FindEngineTests.swift
    ├── HTMLFormatterTests.swift
    ├── HTMLExporterTests.swift
    ├── HTMLToMarkdownTests.swift
    ├── TextMetricsTests.swift
    ├── EmmetExpanderTests.swift
    ├── TagEditingTests.swift
    ├── MultiCursorTests.swift
    ├── HTMLCompletionTests.swift
    ├── CodeStructureTests.swift
    ├── FoldingAndSearchTests.swift
    ├── CustomizationAndSessionTests.swift
    ├── SnippetTests.swift
    └── IDKeyedStoreTests.swift
```

Everything in `Core/` imports only `Foundation`, has no UI dependencies, and is
covered by tests. The AppKit/SwiftUI layer is a thin shell that wires those
functions to the editor.

`Package.swift` declares an `HTMLEditorCore` library target whose `path` points
directly at `HTMLEditor/HTMLEditor/Core/` — the same directory the Xcode app
target compiles via synchronized file groups. There is exactly one copy of every
Core source file; `swift test` builds and tests it without Xcode or a display.

## Requirements

- macOS (recent; the project targets a current deployment SDK)
- Xcode
- WebKit framework (already referenced by the project)

## Getting Started

1. Open `HTMLEditor/HTMLEditor.xcodeproj` in Xcode
2. Select the **HTMLEditor** target
3. Build and run with **⌘R**

If you are setting the project up from scratch, see `SETUP.md`.

## Running the Tests

The pure logic in `Core/` is exercised by an XCTest suite via Swift Package
Manager — no app build or display required:

```bash
swift test
```

Or open `Package.swift` in Xcode and press **⌘U**.

## Keyboard Shortcuts

| Action                      | Shortcut       |
|-----------------------------|----------------|
| New tab                     | `⌘T`           |
| New                         | `⌘N`           |
| Open (new tab)              | `⌘O`           |
| Close tab                   | `⌘W`           |
| Reopen closed tab           | `⇧⌘T`          |
| Save                        | `⌘S`           |
| Save As                     | `⇧⌘S`          |
| Find & replace              | `⌘F`           |
| Go to Line                  | `⌥⌘L`          |
| Reformat document           | `⌥⌘F`          |
| Open in browser             | `⌥⌘B`          |
| Print                       | `⌘P`           |
| Settings                    | `⌘,`           |
| Indent / outdent            | `Tab` / `⇧Tab` |
| Expand Emmet abbreviation   | `⌃E`           |
| Rename matching tag         | `⌃⌘R`          |
| Add next occurrence         | `⌘D`           |
| Split selection into lines  | `⇧⌘L`          |
| Column selection            | `⌃⌘L`          |

## Notes & Caveats

- **Diff markers** (green / orange gutter bars) compare the current buffer to the
  last save or load. They clear when the document is saved. Untitled documents
  with no saved baseline show no markers.
- **CSS color swatches** use a thick underline drawn on `NSTextStorage` attributes;
  they do not insert any characters and do not affect the HTML content.
- **Minimap** mirrors the document with a 2 pt monospaced font. It is read-only
  and provides a structural overview; it is not a clickable scroll target.
- **HTML validation** is structural (tag nesting, a handful of attribute checks).
  It is not a full HTML5 conformance checker. Optional-close elements (`<p>`,
  `<li>`, `<td>`, etc.) are not flagged as unclosed.
- **Breadcrumb bar** recomputes from scratch on each selection change. It is fast
  for typical document sizes but not optimized for multi-megabyte files.
- **Indent and Return apply localized edits**, replacing only the affected range
  rather than the whole document. Reformat still rewrites the whole document in
  one undoable step.
- **Undo history is per tab.** Each tab's text view is cached and reused, so its
  undo stack and selection survive switching away and back. Reloading a file from
  disk resets that document's undo.
- **External-change watching** compares on-disk content to the buffer, so the
  editor's own saves never trigger the reload banner.
- **Syntax highlighting** is tokenizer-based, not a full parser. It handles common
  cases (including embedded CSS/JS) well and is intentionally lightweight.
- **HTML to Markdown conversion** targets clean, editor-produced markup; unusual
  or deeply nested arbitrary web HTML may not round-trip perfectly.
- **Code folding** hides ranges by suppressing glyphs at layout time. Editing near
  folds and multiple overlapping folds are an area to stress-test.
- **Editor-to-preview scroll sync** maps by scroll fraction; alignment is
  approximate when rendered height differs significantly from source height.
- **Console output**: WKWebView's internal helper processes emit sandbox-related
  warnings when running from Xcode. These are harmless.

## Future Extensions

Remaining ideas, contributions welcome:

- **Preview**: bidirectional scroll sync (preview to editor) and element
  inspection / click-to-source
- **Editing**: persist fold state per file across launches; fold-all / unfold-all
- **Minimap**: viewport indicator rectangle + click-to-scroll
- **Validation**: full HTML5 conformance checking beyond structural issues
- **Search**: project-wide search across files on disk beyond the open tabs

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
