# HTML Editor

A lightweight macOS HTML editor built with **SwiftUI**, **AppKit**, and **WebKit**.
It pairs a syntax-highlighted, multi-tab code editor with a live, dark-mode-aware
preview in a single split-view window.

> Edit HTML on the left, watch it render on the right — with line numbers,
> find & replace, smart indentation, one-shot prettifying, HTML/CSS/JS
> highlighting, and export to standalone HTML, minified HTML, or PDF.

## Features

- **Multi-tab document support**
  - Open multiple HTML files in one window
  - Tab strip with per-tab titles, hover-to-close, and a `+` button
  - Each tab remembers its own cursor and selection
  - `⌘T` new tab · `⌘W` close tab

- **Split editor + preview layout**
  - Source on the left, rendered output on the right, in a resizable split view
  - Live preview in a `WKWebView`, refreshed after a short typing debounce

- **Dark-mode-aware preview**
  - The preview follows the system appearance (`color-scheme: light dark`)
    instead of forcing a white background, so pages that don't define their own
    colors render correctly in dark mode

- **Line numbers**
  - A gutter draws 1-based line numbers beside the editor
  - Wrapped lines share a single number (standard editor behavior)

- **Find & replace** (`⌘F`)
  - Next / previous navigation with live match counts ("3 of 12")
  - Case-sensitive, whole-word, and regular-expression options
  - Replace and Replace All
  - The current selection pre-fills the search field

- **Tab / indent support**
  - `Tab` indents the selected lines (or inserts a 2-space soft tab)
  - `⇧Tab` outdents
  - `Return` preserves the current indentation and adds one level after an
    opening tag or `{`

- **HTML formatting / prettify** (`⌥⌘F`)
  - Re-indents the document with consistent 2-space nesting
  - Preserves the contents of `<pre>`, `<textarea>`, `<script>`, and `<style>`

- **Syntax highlighting for HTML, CSS, and JavaScript**
  - HTML: tags, attributes, string values, comments, `<!DOCTYPE>`
  - CSS (inside `<style>`): selectors, properties, values, comments
  - JavaScript (inside `<script>`): keywords, strings, numbers, comments
  - Colors are dynamic and stay legible in both light and dark mode

- **Documents & sessions**
  - Restores the previously open tabs (saved files) on relaunch
  - Recent Files menu (File ▸ Open Recent) and drag-and-drop `.html` to open
  - Watches each open file on disk and offers to reload when it changes
    externally (the editor's own saves don't trigger the prompt)

- **Export options**
  - Standalone HTML (wraps a fragment in a complete document when needed)
  - Minified HTML
  - Markdown (headings, emphasis, links, images, lists, code, blockquotes)
  - PDF and PNG (rendered from the live preview)

- **Customization**
  - Settings panel (`⌘,`) for indent width, editor font size, and theme
  - Pluggable color themes (Default, Midnight, Sepia), each light/dark aware

- **Editing intelligence**
  - **Emmet abbreviation expansion** (`⌃E`): turn `ul>li.item$*3` or
    `nav>ul>li*2>a` into fully indented markup, expanded in place
  - **Auto-close tags**: typing the `>` of an opening tag inserts its matching
    close and parks the caret between them (skips void and self-closing tags)
  - **Linked tag rename** (`⌃⌘R`): selects an opening tag's name and its
    matching close together, so typing renames both at once
  - **Multiple cursors**: add the next occurrence of the selection (`⌘D`), or
    split a selection into one caret per line (`⇧⌘L`)
  - **Column (block) selection** (`⌃⌘L`): turn a selection into a vertical
    block of selections across the spanned lines
  - **Tag & attribute autocompletion**: HTML tag and attribute names complete
    from the caret context (trigger from the Editor menu, or `⌥⎋`)
  - **Bracket & tag-pair match highlighting**: the matching `()[]{}` or the
    matching open/close tag is highlighted as the caret moves
  - **Editable snippet library**: insert reusable snippets from the Editor menu
    and manage them (add / edit / delete) in a sheet; persisted across launches

- **Performance**
  - Tab / Shift-Tab / Return apply *localized* edits (only the affected lines
    change) rather than rewriting the whole document
  - Per-tab undo: each tab keeps its own undo stack across tab switches

- **Toolbar shortcuts for common markup**
  - Headings `H1`–`H3`; inline bold, italic, code; link, image, lists, paragraph
  - Format, Find, and Export actions

- **Status bar**
  - Current file path and cursor line / column

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
│       ├── HtmlEditorApp.swift         # App entry point, menu commands, Settings scene
│       ├── ContentView.swift           # Window layout, toolbar, drag-and-drop, reload banner
│       ├── Workspace.swift             # Open tabs, session restore, recent files
│       ├── DocumentModel.swift         # Per-document text, file I/O, cursor, disk watch
│       ├── TabBarView.swift            # Tab strip
│       ├── FindBar.swift               # Find/replace UI + state
│       ├── EditorView.swift            # NSTextView wrapper (cached per tab; localized edits)
│       ├── EditorCache.swift           # Reuses each tab's text view (per-tab undo)
│       ├── FileWatcher.swift           # Dispatch-source file-change watcher
│       ├── LineNumberRulerView.swift   # Line-number gutter
│       ├── HTMLSyntaxHighlighter.swift # Maps tokens → text attributes
│       ├── EditorTheme.swift           # Resolves the active palette to dynamic colors
│       ├── AppSettingsStore.swift      # Persists EditorSettings; pushes the active theme
│       ├── SettingsView.swift          # Settings panel (indent, font, theme)
│       ├── PreviewView.swift           # WKWebView wrapper (debounced preview)
│       ├── ExportActions.swift         # Save panels; PDF / PNG / Markdown export
│       ├── TextViewStore.swift         # Bridge from UI actions to the live text view
│       ├── SnippetStore.swift          # UserDefaults-backed snippet persistence
│       ├── SnippetsView.swift          # Snippet management sheet
│       └── Core/                       # Pure, Foundation-only, unit-tested logic
│           ├── SyntaxTokenizer.swift   # HTML/CSS/JS tokenizer
│           ├── TextEditingOps.swift    # Tab/indent/newline transforms (+ localized RangeEdit)
│           ├── FindEngine.swift        # Search / replace
│           ├── HTMLFormatter.swift     # Prettify
│           ├── HTMLExporter.swift      # Minify / standalone / filename
│           ├── HTMLToMarkdown.swift    # HTML → Markdown conversion
│           ├── TextMetrics.swift       # Line/column math
│           ├── EmmetExpander.swift     # Emmet abbreviation → HTML
│           ├── TagEditing.swift        # Auto-close + matching-tag ranges
│           ├── MultiCursor.swift       # Next-occurrence / split / column ranges
│           ├── HTMLCompletion.swift    # Tag/attribute completion context
│           ├── CodeStructure.swift     # Bracket matching + fold regions
│           ├── EditorSettings.swift    # Indent / font / theme settings model
│           ├── ThemePalette.swift      # Named color palettes + hex parsing
│           ├── SessionState.swift      # Open-tab session + recent-files models
│           └── Snippet.swift           # Snippet model + library codec
└── Tests/HTMLEditorCoreTests/          # XCTest suite for everything in Core/
```

Everything in `Core/` imports only `Foundation`, has no UI dependencies, and is
covered by tests. The AppKit/SwiftUI layer is a thin shell that wires those
functions to the editor. The same `Core/` sources are compiled both by the app
target and by the `HTMLEditorCore` package library, so the tests validate exactly
the code the app runs — a single source of truth, no duplication.

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

| Action            | Shortcut       |
|-------------------|----------------|
| New tab           | `⌘T`           |
| New               | `⌘N`           |
| Open (new tab)    | `⌘O`           |
| Close tab         | `⌘W`           |
| Save              | `⌘S`           |
| Save As           | `⇧⌘S`          |
| Find & replace    | `⌘F`           |
| Format / prettify | `⌥⌘F`          |
| Settings          | `⌘,`           |
| Indent / outdent  | `Tab` / `⇧Tab` |
| Expand abbreviation | `⌃E`         |
| Rename matching tag | `⌃⌘R`        |
| Add next occurrence | `⌘D`         |
| Split into lines  | `⇧⌘L`          |
| Column selection  | `⌃⌘L`          |
| Autocomplete      | `⌥⎋` / Editor menu |

## Notes & Caveats

- **Indent and Return apply localized edits**, replacing only the affected line
  range rather than the whole document, so editing stays cheap in large files.
  (Format / prettify still rewrites the whole document in one undoable edit,
  since reformatting is inherently document-wide.)
- **Undo history is per tab.** Each tab's text view is cached and reused, so its
  undo stack (and selection) survive switching away and back. Reloading a file
  from disk resets that document's undo.
- **External-change watching** compares on-disk content to the buffer, so the
  editor's own saves never trigger the reload banner.
- **Syntax highlighting is tokenizer-based**, not a full parser. It handles the
  common cases (including embedded CSS/JS) well and is intentionally lightweight.
- **HTML→Markdown conversion** targets clean, editor-produced markup; unusual or
  deeply nested arbitrary web HTML may not round-trip perfectly.
- The line-number gutter aligns numbers to each logical line's first fragment;
  unusual layouts may show minor alignment quirks.

## Future Extensions

Ideas for where the editor could go next, roughly grouped by area. Contributions
are welcome.

**Editing**
- Code folding: collapse multi-line tag regions from the gutter. The foldable
  regions are already detected (`CodeStructure.foldableRegions`); the remaining
  work is the gutter affordance and glyph hiding in the text view.

**Search**
- Find across all open tabs, with a results list
- Incremental highlight of every match in the document while typing

**Documents & sessions**
- Restore unsaved (untitled) tabs across launches, not just saved files
- Reopen the last-closed tab

**Preview**
- A responsive-width / device-size toggle for the preview
- Optional live reload and scroll-position sync between editor and preview

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
