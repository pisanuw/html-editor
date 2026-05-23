import SwiftUI

@main
struct HtmlEditorApp: App {
    // App-wide settings (shared across all windows).
    @StateObject private var settingsStore = AppSettingsStore()

    var body: some Scene {
        // Each new window gets its own independent WorkspaceContainer, which
        // owns its own Workspace, TextViewStore, etc.
        WindowGroup {
            WindowContainer()
                .environmentObject(settingsStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands { AppCommands(settingsStore: settingsStore) }

        Settings {
            SettingsView().environmentObject(settingsStore)
        }
    }
}

// MARK: - Per-window state container

/// Owns all window-scoped state objects so each window is fully independent.
struct WindowContainer: View {
    @StateObject private var workspace     = Workspace()
    @StateObject private var textViewStore = TextViewStore()
    @StateObject private var findState     = FindState()
    @StateObject private var previewStore  = PreviewStore()
    @StateObject private var snippetStore  = SnippetStore()
    @StateObject private var editorCache   = EditorCache()
    @StateObject private var sidebarStore  = FileSidebarStore()

    @EnvironmentObject var settingsStore: AppSettingsStore

    var body: some View {
        ContentView()
            .environmentObject(workspace)
            .environmentObject(textViewStore)
            .environmentObject(findState)
            .environmentObject(previewStore)
            .environmentObject(snippetStore)
            .environmentObject(settingsStore)
            .environmentObject(editorCache)
            .environmentObject(sidebarStore)
            // Expose focused objects so commands can reach the key window's state.
            .focusedSceneObject(workspace)
            .focusedSceneObject(textViewStore)
            .focusedSceneObject(findState)
            .focusedSceneObject(previewStore)
            .focusedSceneObject(snippetStore)
    }
}

// MARK: - App-level commands

/// All menu commands. Uses @FocusedObject to operate on whichever window is key.
struct AppCommands: Commands {
    let settingsStore: AppSettingsStore

    @FocusedObject private var workspace: Workspace?
    @FocusedObject private var textViewStore: TextViewStore?
    @FocusedObject private var findState: FindState?
    @FocusedObject private var previewStore: PreviewStore?
    @FocusedObject private var snippetStore: SnippetStore?

    var body: some Commands {
        // File menu.
        CommandGroup(replacing: .newItem) {
            Button("New Tab")  { workspace?.newTab() }.keyboardShortcut("t")
            Button("New")      { workspace?.newTab() }.keyboardShortcut("n")
            Button("Open…")    { workspace?.openInNewTab() }.keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(workspace?.recentURLs ?? [], id: \.self) { url in
                    Button(url.lastPathComponent) { workspace?.open(url: url) }
                }
            }
            Divider()
            Button("Close Tab") { workspace?.closeActiveTab() }.keyboardShortcut("w")
            Button("Reopen Closed Tab") { workspace?.reopenLastClosed() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Save")     { workspace?.saveActive() }.keyboardShortcut("s")
            Button("Save As…") { workspace?.saveActiveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("Open in Browser") {
                if let html = workspace?.activeDocument.htmlText {
                    ExportActions.openInBrowser(html)
                }
            }
            .keyboardShortcut("b", modifiers: [.command, .option])
            Divider()
            Button("Print…") {
                ExportActions.printPreview(previewStore?.webView)
            }
            .keyboardShortcut("p")
            Divider()
            Menu("Export") {
                Button("Standalone HTML…") {
                    if let html = workspace?.activeDocument.htmlText {
                        ExportActions.exportStandaloneHTML(html)
                    }
                }
                Button("Minified HTML…") {
                    if let html = workspace?.activeDocument.htmlText {
                        ExportActions.exportMinifiedHTML(html)
                    }
                }
                Button("Markdown…") {
                    if let html = workspace?.activeDocument.htmlText {
                        ExportActions.exportMarkdown(html)
                    }
                }
                Divider()
                Button("PDF…") {
                    if let html = workspace?.activeDocument.htmlText {
                        ExportActions.exportPDF(from: previewStore?.webView, sourceHTML: html)
                    }
                }
                Button("PNG Image…") {
                    if let html = workspace?.activeDocument.htmlText {
                        ExportActions.exportPNG(from: previewStore?.webView, sourceHTML: html)
                    }
                }
            }
        }

        // Find / format.
        CommandGroup(after: .textEditing) {
            Button("Find…") {
                let sel = textViewStore?.currentSelectionText ?? ""
                if !sel.isEmpty { findState?.query = sel }
                findState?.isVisible = true
            }
            .keyboardShortcut("f")

            Button("Go to Line…") { findState?.showGoToLine = true }
                .keyboardShortcut("l", modifiers: [.command, .option])

            Button("Reformat Document") {
                if let store = textViewStore {
                    store.replaceAll(with: HTMLFormatter.prettify(store.currentText))
                }
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
        }

        // Editor menu.
        CommandMenu("Editor") {
            Button("Expand Abbreviation") { textViewStore?.expandEmmet() }
                .keyboardShortcut("e", modifiers: .control)
            Button("Autocomplete Tag / Attribute") { textViewStore?.triggerCompletion() }
            Divider()
            Button("Rename Matching Tag") { textViewStore?.renameTagAtCaret() }
                .keyboardShortcut("r", modifiers: [.command, .control])
            Button("Add Next Occurrence") { textViewStore?.addNextOccurrence() }
                .keyboardShortcut("d", modifiers: .command)
            Button("Split Selection into Lines") { textViewStore?.splitSelectionIntoLines() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Column Selection") { textViewStore?.columnSelectFromSelection() }
                .keyboardShortcut("l", modifiers: [.command, .control])
            Divider()
            Menu("Snippets") {
                ForEach(snippetStore?.library.snippets ?? []) { snippet in
                    Button(snippet.name.isEmpty ? snippet.trigger : snippet.name) {
                        textViewStore?.insertSnippet(snippet.body)
                    }
                }
                Divider()
                Button("Manage Snippets…") { snippetStore?.showingManager = true }
            }
        }
    }
}
