import SwiftUI

@main
struct HtmlEditorApp: App {
    @StateObject private var workspace = Workspace()
    @StateObject private var textViewStore = TextViewStore()
    @StateObject private var findState = FindState()
    @StateObject private var previewStore = PreviewStore()
    @StateObject private var snippetStore = SnippetStore()
    @StateObject private var settingsStore = AppSettingsStore()
    @StateObject private var editorCache = EditorCache()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspace)
                .environmentObject(textViewStore)
                .environmentObject(findState)
                .environmentObject(previewStore)
                .environmentObject(snippetStore)
                .environmentObject(settingsStore)
                .environmentObject(editorCache)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // File menu.
            CommandGroup(replacing: .newItem) {
                Button("New Tab")   { workspace.newTab() }.keyboardShortcut("t")
                Button("New")       { workspace.newTab() }.keyboardShortcut("n")
                Button("Open…")     { workspace.openInNewTab() }.keyboardShortcut("o")
                Menu("Open Recent") {
                    ForEach(workspace.recentURLs, id: \.self) { url in
                        Button(url.lastPathComponent) { workspace.open(url: url) }
                    }
                }
                Divider()
                Button("Close Tab") { workspace.closeActiveTab() }.keyboardShortcut("w")
                Button("Reopen Closed Tab") { workspace.reopenLastClosed() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Divider()
                Button("Save")      { workspace.saveActive() }.keyboardShortcut("s")
                Button("Save As…")  { workspace.saveActiveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Menu("Export") {
                    Button("Standalone HTML…") {
                        ExportActions.exportStandaloneHTML(workspace.activeDocument.htmlText)
                    }
                    Button("Minified HTML…") {
                        ExportActions.exportMinifiedHTML(workspace.activeDocument.htmlText)
                    }
                    Button("Markdown…") {
                        ExportActions.exportMarkdown(workspace.activeDocument.htmlText)
                    }
                    Divider()
                    Button("PDF…") {
                        ExportActions.exportPDF(from: previewStore.webView,
                                                sourceHTML: workspace.activeDocument.htmlText)
                    }
                    Button("PNG Image…") {
                        ExportActions.exportPNG(from: previewStore.webView,
                                                sourceHTML: workspace.activeDocument.htmlText)
                    }
                }
            }

            // Find / format, alongside the standard text-editing items.
            CommandGroup(after: .textEditing) {
                Button("Find…") { showFind() }
                    .keyboardShortcut("f")
                Button("Reformat Document") { reformat() }
                    .keyboardShortcut("f", modifiers: [.command, .option])
            }

            // Editing features: Emmet, completion, multi-cursor, snippets.
            CommandMenu("Editor") {
                Button("Expand Abbreviation") { textViewStore.expandEmmet() }
                    .keyboardShortcut("e", modifiers: .control)
                Button("Autocomplete Tag / Attribute") { textViewStore.triggerCompletion() }
                Divider()
                Button("Rename Matching Tag") { textViewStore.renameTagAtCaret() }
                    .keyboardShortcut("r", modifiers: [.command, .control])
                Button("Add Next Occurrence") { textViewStore.addNextOccurrence() }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Split Selection into Lines") { textViewStore.splitSelectionIntoLines() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Column Selection") { textViewStore.columnSelectFromSelection() }
                    .keyboardShortcut("l", modifiers: [.command, .control])
                Divider()
                Menu("Snippets") {
                    ForEach(snippetStore.library.snippets) { snippet in
                        Button(snippet.name.isEmpty ? snippet.trigger : snippet.name) {
                            textViewStore.insertSnippet(snippet.body)
                        }
                    }
                    Divider()
                    Button("Manage Snippets…") { snippetStore.showingManager = true }
                }
            }
        }

        Settings {
            SettingsView().environmentObject(settingsStore)
        }
    }

    private func showFind() {
        let selected = textViewStore.currentSelectionText
        if !selected.isEmpty { findState.query = selected }
        findState.isVisible = true
    }

    private func reformat() {
        textViewStore.replaceAll(with: HTMLFormatter.prettify(textViewStore.currentText))
    }
}
