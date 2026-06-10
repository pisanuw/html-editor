# HTML Editor — Xcode Setup

The repository already contains a configured Xcode project. In most cases you can
simply open it and run:

```text
HTMLEditor/HTMLEditor.xcodeproj
```

Press **⌘R** to build and run. The project uses Xcode's synchronized file groups,
so every `.swift` file under `HTMLEditor/HTMLEditor/` (including the `Core/`
subfolder) is part of the app target automatically — no manual file management is
needed when files are added.

## Running the unit tests

The pure logic lives in `HTMLEditor/HTMLEditor/Core/` and is tested through Swift
Package Manager from the repository root:

```bash
swift test
```

Or open `Package.swift` in Xcode and press **⌘U**.

---

## Recreating the project from scratch (only if needed)

If you ever need to rebuild the Xcode project from nothing:

1. **Open Xcode** → File → New → Project
2. Choose **macOS → App** → Next
3. Fill in:
   - Product Name: `HTMLEditor`
   - Bundle Identifier: `edu.uw.HTMLEditor` (or your own)
   - Interface: **SwiftUI**
   - Language: **Swift**
4. Set the save location to **this repo folder** (`html-editor/`) → Create
5. Delete the generated `ContentView.swift` and `HTMLEditorApp.swift` stubs
   (Move to Trash).
6. Add the existing sources: right-click the **HTMLEditor group** → Add Files…,
   then add every `.swift` file in `html-editor/HTMLEditor/HTMLEditor/` **and**
   the `Core/` folder (add it as a folder reference / group).

The source files (app layer):

```text
HtmlEditorApp.swift        Workspace.swift            EditorView.swift
ContentView.swift          DocumentModel.swift        EditorCache.swift
TabBarView.swift           TextViewStore.swift        FoldingController.swift
FindBar.swift              GoToLineView.swift         FileWatcher.swift
HTMLSyntaxHighlighter.swift EditorTheme.swift         AppSettingsStore.swift
LineNumberRulerView.swift  BreadcrumbBarView.swift    MinimapView.swift
PreviewView.swift          ExportActions.swift        SettingsView.swift
FindResultsView.swift      FileSidebarView.swift      ValidationPanelView.swift
SnippetStore.swift         SnippetsView.swift
```

Core/ (pure Foundation logic, unit-tested via SwiftPM):

```text
SyntaxTokenizer.swift   TextEditingOps.swift   FindEngine.swift
HTMLFormatter.swift     HTMLExporter.swift     HTMLToMarkdown.swift
HTMLValidator.swift     HTMLBreadcrumb.swift   TextMetrics.swift
EmmetExpander.swift     TagEditing.swift       MultiCursor.swift
HTMLCompletion.swift    CodeStructure.swift    FoldingModel.swift
MultiFileSearch.swift   PreviewWidth.swift     EditorSettings.swift
ThemePalette.swift      SessionState.swift     Snippet.swift
```

## WebKit framework

`PreviewView.swift` uses `WKWebView` from WebKit. If a rebuilt project does not
link it automatically:

1. Select the **project** → **HTMLEditor target**
2. **General → Frameworks, Libraries, and Embedded Content**
3. **+** → search "WebKit" → add **WebKit.framework**

## Keyboard shortcuts

| Action            | Shortcut |
|-------------------|----------|
| New tab           | ⌘T       |
| Open (new tab)    | ⌘O       |
| Close tab         | ⌘W       |
| Save              | ⌘S       |
| Save As           | ⇧⌘S      |
| Find & replace    | ⌘F       |
| Format / prettify | ⌥⌘F      |
