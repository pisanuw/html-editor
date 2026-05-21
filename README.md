# HTML Editor

A lightweight macOS HTML editor built with **SwiftUI**, **AppKit**, and **WebKit**.  
It provides a split-view editing experience with:

- a syntax-highlighted HTML editor
- a live preview pane
- quick toolbar actions for common HTML tags
- basic file operations for creating, opening, and saving `.html` files

## Features

- **Split editor + preview layout**
  - Edit HTML on the left
  - See rendered output on the right

- **Live preview**
  - HTML is rendered in a `WKWebView`
  - Preview updates automatically after a short debounce while typing

- **Syntax highlighting**
  - Highlights:
    - HTML tags
    - attributes
    - string values
    - comments
    - `<!DOCTYPE ...>`

- **Toolbar shortcuts for common markup**
  - Headings: `H1`, `H2`, `H3`
  - Inline formatting: bold, italic, code
  - Structure helpers: link, image, unordered list, ordered list, paragraph

- **Document actions**
  - New
  - Open HTML file
  - Save
  - Save As

- **Status bar**
  - Shows current file path
  - Displays cursor line and column

## Built With

- **Swift**
- **SwiftUI**
- **AppKit**
- **WebKit**
- **Xcode**

## Project Structure

```text
html-editor/
├── HTMLEditor/
│   ├── HTMLEditor.xcodeproj
│   └── HTMLEditor/
│       ├── HtmlEditorApp.swift
│       ├── ContentView.swift
│       ├── DocumentModel.swift
│       ├── TextViewStore.swift
│       ├── HTMLSyntaxHighlighter.swift
│       ├── EditorView.swift
│       ├── PreviewView.swift
│       └── Assets.xcassets
└── SETUP.md
```

## Main Components

- **`HtmlEditorApp.swift`**  
  App entry point. Sets up the shared document model and editor state.

- **`ContentView.swift`**  
  Main UI layout with split editor/preview view, toolbar, and status bar.

- **`DocumentModel.swift`**  
  Handles document state, file loading/saving, window title, and cursor position tracking.

- **`EditorView.swift`**  
  Wraps `NSTextView` for editable plain-text HTML authoring with syntax highlighting.

- **`PreviewView.swift`**  
  Wraps `WKWebView` for rendering live HTML previews.

- **`HTMLSyntaxHighlighter.swift`**  
  Applies simple regex-based syntax coloring to the editor text.

- **`TextViewStore.swift`**  
  Keeps a reference to the active text view so toolbar actions can insert or wrap HTML snippets.

## Requirements

- macOS
- Xcode
- Swift / SwiftUI support
- WebKit framework

## Getting Started

### Open the project

Open the Xcode project:

```text
HTMLEditor/HTMLEditor.xcodeproj
```

### Build and run

1. Open the project in Xcode
2. Select the **HTMLEditor** target
3. Build and run with **⌘R**

## Keyboard Shortcuts

| Action   | Shortcut |
|----------|----------|
| New      | `⌘N`     |
| Open     | `⌘O`     |
| Save     | `⌘S`     |
| Save As  | `⇧⌘S`    |

## Default Document Template

New documents start with a basic HTML template including:

- `<!DOCTYPE html>`
- `<meta charset="UTF-8">`
- a page title
- simple default body styling
- starter heading and paragraph content

## Notes

- The preview uses a white background for consistent rendering.
- The editor uses a monospaced font for code editing.
- Syntax highlighting is intentionally simple and regex-based, making it lightweight and easy to understand.

## Setup Help

If you need step-by-step Xcode setup instructions, see:

```text
SETUP.md
```

## Future Improvements

Potential enhancements for the project:

- line numbers
- find/replace
- tab/indent support improvements
- HTML formatting / prettify
- CSS and JavaScript syntax highlighting
- multi-tab document support
- export options
- dark-mode-aware preview styling

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
