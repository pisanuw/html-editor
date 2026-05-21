# HTML Editor — Xcode Setup

## One-time project creation (< 5 minutes)

1. **Open Xcode** → File → New → Project
2. Choose **macOS → App** → Next
3. Fill in:
   - Product Name: `HTMLEditor`
   - Bundle Identifier: `edu.uw.HTMLEditor` (or whatever you like)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" (optional)
4. Set the save location to **this repo folder** (`html-editor/`) → Create

Xcode creates `HTMLEditor/ContentView.swift` and `HTMLEditor/HTMLEditorApp.swift` as stubs.

## Replace the generated stubs with the source files

1. In the Xcode Project Navigator (left panel), select and **delete** the two generated files:
   - `ContentView.swift`
   - `HTMLEditorApp.swift`
   (choose "Move to Trash" when prompted)

2. Right-click the **HTMLEditor group** in the Navigator → Add Files to "HTMLEditor"…
3. Navigate to `html-editor/HTMLEditor/` and select **all 7 `.swift` files** → Add

The files to add:
- `HtmlEditorApp.swift`
- `ContentView.swift`
- `DocumentModel.swift`
- `TextViewStore.swift`
- `HTMLSyntaxHighlighter.swift`
- `EditorView.swift`
- `PreviewView.swift`

## Add the WebKit framework

`PreviewView.swift` uses `WKWebView` from WebKit:

1. Click the **project** (blue icon, top of Navigator)
2. Select the **HTMLEditor target**
3. Go to **General → Frameworks, Libraries, and Embedded Content**
4. Click **+** → search "WebKit" → Add **WebKit.framework**

## Build & Run

Press **⌘R**. The app opens with a split window:
- Left: syntax-highlighted HTML editor
- Right: live preview (updates 350 ms after you stop typing)

## Keyboard shortcuts

| Action     | Shortcut      |
|------------|---------------|
| New        | ⌘N            |
| Open       | ⌘O            |
| Save       | ⌘S            |
| Save As    | ⇧⌘S          |

Toolbar buttons: H1 H2 H3 · **B** *I* `{}` · 🔗 🖼 • # ¶
