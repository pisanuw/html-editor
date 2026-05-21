import SwiftUI

@main
struct HtmlEditorApp: App {
    @StateObject private var workspace = Workspace()
    @StateObject private var textViewStore = TextViewStore()
    @StateObject private var findState = FindState()
    @StateObject private var previewStore = PreviewStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspace)
                .environmentObject(textViewStore)
                .environmentObject(findState)
                .environmentObject(previewStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // File menu.
            CommandGroup(replacing: .newItem) {
                Button("New Tab")   { workspace.newTab() }.keyboardShortcut("t")
                Button("New")       { workspace.newTab() }.keyboardShortcut("n")
                Button("Open…")     { workspace.openInNewTab() }.keyboardShortcut("o")
                Divider()
                Button("Close Tab") { workspace.closeActiveTab() }.keyboardShortcut("w")
                Divider()
                Button("Save")      { workspace.activeDocument.saveDocument() }.keyboardShortcut("s")
                Button("Save As…")  { workspace.activeDocument.saveDocumentAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Menu("Export") {
                    Button("Standalone HTML…") {
                        ExportActions.exportStandaloneHTML(workspace.activeDocument.htmlText)
                    }
                    Button("Minified HTML…") {
                        ExportActions.exportMinifiedHTML(workspace.activeDocument.htmlText)
                    }
                    Button("PDF…") {
                        ExportActions.exportPDF(from: previewStore.webView,
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
